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

  depends_on = [helm_release.metallb_config]
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

moved {
  from = helm_release.rancher
  to   = helm_release.rancher[0]
}

resource "helm_release" "rancher" {
  count            = var.enable_rancher ? 1 : 0
  name             = "rancher"
  repository       = "https://releases.rancher.com/server-charts/stable"
  chart            = "rancher"
  version          = "2.13.3"
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
