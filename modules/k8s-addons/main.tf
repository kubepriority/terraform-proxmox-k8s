resource "helm_release" "metallb" {
  name             = "metallb"
  repository       = "https://metallb.github.io/metallb"
  chart            = "metallb"
  version          = "0.14.9"
  namespace        = "metallb-system"
  create_namespace = true
}

resource "helm_release" "metallb_config" {
  name      = "metallb-config"
  chart     = "${path.module}/../../charts/metallb-config"
  namespace = "metallb-system"

  set {
    name  = "pool.addresses"
    value = var.metallb_pool
  }

  depends_on = [helm_release.metallb]
}

resource "helm_release" "ingress_nginx" {
  name             = "ingress-nginx"
  repository       = "https://kubernetes.github.io/ingress-nginx"
  chart            = "ingress-nginx"
  version          = "4.12.1"
  namespace        = "ingress-nginx"
  create_namespace = true

  set {
    name  = "controller.service.annotations.metallb\\.universe\\.tf/loadBalancerIPs"
    value = var.ingress_vip
  }

  set {
    name  = "controller.extraArgs.default-ssl-certificate"
    value = "ingress-nginx/ingress-nginx-tls"
  }

  set {
    name  = "controller.metrics.enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.service.enabled"
    value = "true"
  }

  set {
    name  = "controller.metrics.service.type"
    value = "ClusterIP"
  }

  set {
    name  = "controller.metrics.service.servicePort"
    value = "10254"
  }

  depends_on = [
    helm_release.metallb_config
  ]
}

resource "helm_release" "cert_manager" {
  name             = "cert-manager"
  repository       = "https://charts.jetstack.io"
  chart            = "cert-manager"
  version          = "v1.16.3"
  namespace        = "cert-manager"
  create_namespace = true

  set {
    name  = "crds.enabled"
    value = "true"
  }
}

# gcpSaKeyJson vai por values/yamlencode, não por set: o JSON da chave contém
# vírgulas e o parser do set quebra valores em vírgula.
resource "helm_release" "cert_infra" {
  name      = "cert-infra"
  chart     = "${path.module}/../../charts/cert-infra"
  namespace = "cert-manager"

  values = [
    yamlencode({
      acmeEmail    = var.acme_email
      gcpProject   = var.gcp_project
      domain       = var.domain
      gcpSaKeyJson = file(var.gcp_sa_key_path)
    })
  ]

  depends_on = [helm_release.cert_manager, helm_release.ingress_nginx]
}

moved {
  from = helm_release.metrics_server
  to   = helm_release.metrics_server[0]
}

resource "helm_release" "metrics_server" {
  count      = var.enable_metrics_server ? 1 : 0
  name       = "metrics-server"
  repository = "https://kubernetes-sigs.github.io/metrics-server/"
  chart      = "metrics-server"
  version    = "3.12.2"
  namespace  = "kube-system"

  # kubeadm: kubelet serve com cert self-signed; sem isso o metrics-server
  # sobe mas nenhuma metrica e coletada (erro de TLS).
  values = [
    yamlencode({
      args = ["--kubelet-insecure-tls"]
    })
  ]
}

resource "helm_release" "longhorn" {
  count            = var.storage_backend == "longhorn" ? 1 : 0
  name             = "longhorn"
  repository       = "https://charts.longhorn.io"
  chart            = "longhorn"
  version          = "1.12.0"
  namespace        = "longhorn-system"
  create_namespace = true
  timeout          = 600

  values = [
    yamlencode({
      defaultSettings = {
        # Disco dedicado de 100GB montado pelo cloud-init em todos os nos
        defaultDataPath = "/var/openebs/local"
      }
      persistence = {
        defaultClass             = true
        defaultClassReplicaCount = var.storage_replicas
      }
    })
  ]
}

# SCs nomeadas por convencao de uso: longhorn-fs (Filesystem) e
# longhorn-block (Block). Nota: volumeMode e sempre decidido no PVC.
resource "helm_release" "longhorn_classes" {
  count     = var.storage_backend == "longhorn" ? 1 : 0
  name      = "longhorn-classes"
  chart     = "${path.module}/../../charts/longhorn-classes"
  namespace = "longhorn-system"

  set {
    name  = "replicas"
    value = var.storage_replicas
  }

  depends_on = [helm_release.longhorn]
}

# Rook-Ceph (storage_backend = "ceph"): operator + cluster. OSDs usam o disco
# de dados raw dos workers (/dev/vdb, virtio1). SCs: ceph-block (RBD, default)
# e ceph-fs (CephFS RWX). Object store (RGW) fora por YAGNI.
resource "helm_release" "rook_ceph" {
  count            = var.storage_backend == "ceph" ? 1 : 0
  name             = "rook-ceph"
  repository       = "https://charts.rook.io/release"
  chart            = "rook-ceph"
  version          = "v1.20.3"
  namespace        = "rook-ceph"
  create_namespace = true
  timeout          = 600

  values = [
    yamlencode({
      # O default do chart e prefixo vazio, que faz o operator procurar SAs
      # "rbd-ctrlplugin-sa" etc. O bundle de RBAC upstream (chart
      # ceph-csi-drivers abaixo) cria as SAs com o prefixo do projeto, entao os
      # dois lados precisam combinar — sem isso os plugins ficam FailedCreate.
      "ceph-csi-operator" = {
        controllerManager = {
          manager = {
            env = {
              csiServiceAccountPrefix = "ceph-csi-operator-"
            }
          }
        }
      }
    })
  ]
}

# O chart rook-ceph instala o ceph-csi-operator mas nao cria os Driver CRs nem
# as SAs/RBAC dos plugins; sem eles nenhum provisioner sobe e todo PVC fica
# Pending. Precisa vir antes do cluster para as SCs terem provisioner ao nascer.
resource "helm_release" "ceph_csi_drivers" {
  count     = var.storage_backend == "ceph" ? 1 : 0
  name      = "ceph-csi-drivers"
  chart     = "${path.module}/../../charts/ceph-csi-drivers"
  namespace = "rook-ceph"
  timeout   = 300

  depends_on = [helm_release.rook_ceph]
}

resource "helm_release" "rook_ceph_cluster" {
  count      = var.storage_backend == "ceph" ? 1 : 0
  name       = "rook-ceph-cluster"
  repository = "https://charts.rook.io/release"
  chart      = "rook-ceph-cluster"
  version    = "v1.20.3"
  namespace  = "rook-ceph"
  # OSDs so ficam prontos depois de mon quorum + prepare jobs; 20 min de folga.
  timeout = 1200

  values = [
    yamlencode({
      operatorNamespace = "rook-ceph"
      toolbox           = { enabled = true }
      cephClusterSpec = {
        dashboard = { enabled = false }
        mon       = { count = 3, allowMultiplePerNode = false }
        storage = {
          useAllNodes   = true
          useAllDevices = false
          deviceFilter  = "^vdb$"
        }
      }
      cephBlockPools = [{
        name = "ceph-blockpool"
        spec = {
          failureDomain = "host"
          replicated    = { size = var.storage_replicas }
        }
        storageClass = {
          enabled              = true
          name                 = "ceph-block"
          isDefault            = true
          reclaimPolicy        = "Delete"
          allowVolumeExpansion = true
          parameters = {
            imageFormat                                             = "2"
            imageFeatures                                           = "layering"
            "csi.storage.k8s.io/fstype"                             = "ext4"
            "csi.storage.k8s.io/provisioner-secret-name"            = "rook-csi-rbd-provisioner"
            "csi.storage.k8s.io/provisioner-secret-namespace"       = "rook-ceph"
            "csi.storage.k8s.io/controller-expand-secret-name"      = "rook-csi-rbd-provisioner"
            "csi.storage.k8s.io/controller-expand-secret-namespace" = "rook-ceph"
            "csi.storage.k8s.io/node-stage-secret-name"             = "rook-csi-rbd-node"
            "csi.storage.k8s.io/node-stage-secret-namespace"        = "rook-ceph"
          }
        }
      }]
      cephFileSystems = [{
        name = "ceph-filesystem"
        spec = {
          metadataPool = { replicated = { size = var.storage_replicas } }
          dataPools = [{
            name          = "data0"
            failureDomain = "host"
            replicated    = { size = var.storage_replicas }
          }]
          metadataServer = {
            activeCount   = 1
            activeStandby = true
          }
        }
        storageClass = {
          enabled              = true
          name                 = "ceph-fs"
          isDefault            = false
          pool                 = "data0"
          reclaimPolicy        = "Delete"
          allowVolumeExpansion = true
          parameters = {
            "csi.storage.k8s.io/provisioner-secret-name"            = "rook-csi-cephfs-provisioner"
            "csi.storage.k8s.io/provisioner-secret-namespace"       = "rook-ceph"
            "csi.storage.k8s.io/controller-expand-secret-name"      = "rook-csi-cephfs-provisioner"
            "csi.storage.k8s.io/controller-expand-secret-namespace" = "rook-ceph"
            "csi.storage.k8s.io/node-stage-secret-name"             = "rook-csi-cephfs-node"
            "csi.storage.k8s.io/node-stage-secret-namespace"        = "rook-ceph"
          }
        }
      }]
      cephObjectStores = []
    })
  ]

  depends_on = [helm_release.rook_ceph, helm_release.ceph_csi_drivers]
}

moved {
  from = helm_release.rancher
  to   = helm_release.rancher[0]
}

resource "helm_release" "rancher" {
  count            = var.enable_rancher ? 1 : 0
  name             = "rancher"
  repository       = "https://releases.rancher.com/server-charts/stable"
  chart            = "rancher"
  # 2.13.x declara kubeVersion < 1.35.0-0 e o helm recusa instalar no k8s 1.35;
  # 2.14.x aceita ate < 1.36.0-0.
  version          = "2.14.3"
  namespace        = "cattle-system"
  create_namespace = true
  timeout          = 600

  set {
    name  = "hostname"
    value = var.rancher_hostname
  }

  set {
    name  = "replicas"
    value = var.rancher_replicas
  }

  set {
    name  = "ingress.ingressClassName"
    value = "nginx"
  }

  # cert-manager (ingress-shim) emite o certificado do Rancher automaticamente
  # a partir desta annotation; o chart referencia o secret tls-rancher-ingress.
  set {
    name  = "ingress.tls.source"
    value = "secret"
  }

  set {
    name  = "ingress.extraAnnotations.cert-manager\\.io/cluster-issuer"
    value = "letsencrypt-dns01-prd"
  }

  # Hardware modesto: Rancher leva mais que os 2 min default para subir;
  # startup probe curta demais derruba o pod em loop.
  set {
    name  = "startupProbe.failureThreshold"
    value = "60"
  }

  set_sensitive {
    name  = "bootstrapPassword"
    value = var.rancher_bootstrap_password
  }

  depends_on = [helm_release.cert_infra, helm_release.ingress_nginx]
}

resource "helm_release" "argocd" {
  count            = var.enable_argocd ? 1 : 0
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  version          = "7.8.2"
  namespace        = "argocd"
  create_namespace = true
  timeout          = 600

  set {
    name  = "global.domain"
    value = var.argocd_hostname
  }

  set {
    name  = "server.ingress.enabled"
    value = "true"
  }

  set {
    name  = "server.ingress.ingressClassName"
    value = "nginx"
  }

  # cert-manager (ingress-shim) emite o certificado a partir desta annotation.
  set {
    name  = "server.ingress.annotations.cert-manager\\.io/cluster-issuer"
    value = "letsencrypt-dns01-prd"
  }

  set {
    name  = "server.ingress.tls"
    value = "true"
  }

  # TLS termina no ingress-nginx; sem isso o argocd-server responde HTTPS
  # proprio e o ingress entra em loop de redirect.
  set {
    name  = "configs.params.server\\.insecure"
    value = "true"
  }

  depends_on = [helm_release.cert_infra, helm_release.ingress_nginx]
}

# Passwords do mariadb/redis ficam nos defaults do chart (geradas no cluster);
# ingress com TLS do cert-manager e backend HTTPS (passbolt força SSL interno).
resource "helm_release" "passbolt" {
  count            = var.enable_passbolt ? 1 : 0
  name             = "passbolt"
  repository       = "https://download.passbolt.com/charts/passbolt"
  chart            = "passbolt"
  version          = "2.1.1"
  namespace        = "passbolt"
  create_namespace = true
  timeout          = 900

  values = [yamlencode({
    passboltEnv = {
      plain = {
        APP_FULL_BASE_URL  = "https://${var.passbolt_hostname}"
        PASSBOLT_SSL_FORCE = true
      }
    }
    ingress = {
      enabled   = true
      className = "nginx"
      annotations = {
        "cert-manager.io/cluster-issuer"                = "letsencrypt-dns01-prd"
        "nginx.ingress.kubernetes.io/backend-protocol"  = "HTTPS"
      }
      hosts = [{
        host = var.passbolt_hostname
        paths = [{
          path     = "/"
          port     = "https"
          pathType = "ImplementationSpecific"
        }]
      }]
      tls = [{
        autogenerate   = false
        existingSecret = "passbolt-tls"
        hosts          = [var.passbolt_hostname]
      }]
    }
  })]

  depends_on = [helm_release.cert_infra, helm_release.ingress_nginx, helm_release.longhorn_classes, helm_release.rook_ceph_cluster]
}
