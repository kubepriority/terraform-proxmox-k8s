variable "metallb_pool" {
  type        = string
  description = "Faixa de IPs do IPAddressPool do MetalLB"
  default     = "10.10.10.100-10.10.10.110"
}

variable "ingress_vip" {
  type        = string
  description = "IP fixo (dentro do pool) do Service LoadBalancer do ingress-nginx"
  default     = "10.10.10.100"
}

variable "acme_email" {
  type        = string
  description = "E-mail da conta ACME (Let's Encrypt)"
  default     = "hudson.erik@gmail.com"
}

variable "gcp_project" {
  type        = string
  description = "Projeto GCP dono da zona Cloud DNS"
  default     = "project-90293a0a-5d49-4604-a23"
}

variable "gcp_sa_key_path" {
  type        = string
  description = "Caminho local do key.json da service account cert-manager-dns01"
  sensitive   = true
}

variable "domain" {
  type        = string
  description = "Domínio base do certificado wildcard"
  default     = "kubepriority.com.br"
}

variable "rancher_hostname" {
  type        = string
  description = "Hostname público do Rancher"
  default     = "rancher.kubepriority.com.br"
}

variable "rancher_replicas" {
  type        = string
  description = "Número de réplicas do Rancher"
  default     = "1"
}

variable "rancher_bootstrap_password" {
  type        = string
  description = "Senha inicial do admin do Rancher"
  sensitive   = true
}

variable "enable_rancher" {
  type        = bool
  description = "Instala o Rancher"
  default     = true
}

variable "enable_metrics_server" {
  type        = bool
  description = "Instala o metrics-server"
  default     = true
}

variable "storage_backend" {
  type        = string
  description = "longhorn instala Longhorn + SCs longhorn-*; ceph instala Rook-Ceph + SCs ceph-*"
}

variable "storage_replicas" {
  type        = number
  description = "Réplicas por volume (Longhorn) / size do replicated pool (Ceph)"
  default     = 3
}

variable "rancher_chart_version" {
  type        = string
  description = "Versão do chart Helm do Rancher (2.13.x recusa k8s >= 1.35; 2.14.x exige >= ... < 1.36)"
  default     = "2.13.3"
}

variable "enable_argocd" {
  type        = bool
  description = "Instala o Argo CD (GitOps)"
  default     = true
}

variable "argocd_hostname" {
  type        = string
  description = "Hostname público do Argo CD"
  default     = "argocd.kubepriority.com.br"
}

variable "enable_passbolt" {
  type        = bool
  description = "Instala o Passbolt (gerenciador de senhas)"
  default     = true
}

variable "passbolt_hostname" {
  type        = string
  description = "Hostname público do Passbolt"
  default     = "passbolt.kubepriority.com.br"
}

variable "smtp_host" {
  type        = string
  description = "Host SMTP do Passbolt (vazio = mantem defaults do chart, sem envio de e-mail)"
  default     = ""
}

variable "smtp_port" {
  type        = number
  description = "Porta SMTP (587 = STARTTLS)"
  default     = 587
}

variable "smtp_username" {
  type        = string
  description = "Usuario SMTP"
  sensitive   = true
  default     = ""
}

variable "smtp_password" {
  type        = string
  description = "Senha SMTP"
  sensitive   = true
  default     = ""
}

variable "smtp_from" {
  type        = string
  description = "Remetente dos e-mails do Passbolt (dominio precisa estar verificado no provedor)"
  default     = ""
}

variable "passbolt_ha" {
  type        = bool
  description = "true mantem mariadb replicado + redis sentinel (3 nos) + 2 apps; false deixa instancia unica. Trocar para false RECRIA o banco (PVC antigo vira orfao)"
  default     = true
}

variable "passbolt_public_registration" {
  type        = bool
  description = "Permite auto-cadastro no Passbolt. false = so por convite do admin"
  default     = true
}

variable "smtp_from_name" {
  type        = string
  description = "Nome exibido como remetente"
  default     = "Passbolt"
}
