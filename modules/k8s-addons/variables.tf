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
