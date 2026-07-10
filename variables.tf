variable "proxmox_endpoint" {
  description = "Proxmox server address"
  type        = string
}

variable "proxmox_user_name" {
  description = "Proxmox api token id"
  type        = string
}

variable "proxmox_user_password" {
  description = "Proxmox api token secret"
  type        = string
  sensitive   = true
}

variable "proxmox_vm_user" {
  description = "Linux username"
  type        = string
}

variable "proxmox_vm_password" {
  description = "Linux user password"
  type        = string
  sensitive   = true
}

variable "proxmox_number_of_vm_k8s_worker_node" {
  description = "Number of k8s worker nodes"
  type        = string
  default     = "3"
}

variable "proxmox_number_of_vm_k8s_control_plane" {
  description = "Number of k8s control plane nodes"
  type        = string
  default     = "1"
}

variable "k8s_control_plane_ip_start" {
  description = "First IP of the k8s control plane address range"
  type        = string
  default     = "50"
}

variable "k8s_worker_ip_start" {
  description = "First IP of the k8s worker address range"
  type        = string
  default     = "60"
}

variable "proxmox_node_name" {
  description = "Proxmox server name"
  type        = string
  default     = "proxmox"
}

variable "proxmox_network_bridge" {
  description = "Proxmox network bridge for VM NICs"
  type        = string
  default     = "vmbr1"
}

variable "proxmox_network_prefix" {
  description = "First three octets of the VM network (e.g. 10.10.10)"
  type        = string
  default     = "10.10.10"
}

variable "proxmox_datastore_name" {
  description = "Proxmox datastore"
  type        = string
  default     = "local"
}
variable "kubeconfig_path" {
  type        = string
  description = "Caminho do kubeconfig do cluster (gerado por scripts/get-kubeconfig.sh)"
  default     = "./kubeconfig"
}

variable "gcp_sa_key_path" {
  type        = string
  description = "Caminho local do key.json da service account cert-manager-dns01"
  sensitive   = true
  default     = "./kubernetes/lets-encrypt-dns-google/cert-manager-dns01.json"
}

variable "rancher_bootstrap_password" {
  type        = string
  description = "Senha inicial do admin do Rancher"
  sensitive   = true
}

variable "domain" {
  type        = string
  description = "Domínio base público (wildcard TLS e registros DNS)"
  default     = "kubepriority.com.br"
}

variable "gcp_project" {
  type        = string
  description = "Projeto GCP dono da zona Cloud DNS"
  default     = "project-90293a0a-5d49-4604-a23"
}

variable "dns_zone" {
  type        = string
  description = "Nome da managed zone no Cloud DNS"
  default     = "kubepriority-zone"
}
