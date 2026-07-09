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
