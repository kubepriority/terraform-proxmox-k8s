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
  description = "Proxmox datastore para snippets e imagens (precisa aceitar iso/snippets)"
  type        = string
  default     = "local"
}

variable "proxmox_vm_datastore_name" {
  description = "Datastore dos discos das VMs (pool ZFS 'data')"
  type        = string
  default     = "data"
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

variable "enable_argocd" {
  type        = bool
  description = "Instala o Argo CD (GitOps)"
  default     = true
}

variable "enable_passbolt" {
  type        = bool
  description = "Instala o Passbolt (gerenciador de senhas)"
  default     = true
}

variable "enable_vpn" {
  type        = bool
  description = "Configura WireGuard no host Proxmox (clientes + site-to-site)"
  default     = true
}

variable "vpn_cidr" {
  type        = string
  description = "Rede interna da VPN WireGuard"
  default     = "10.20.0.0/24"
}

variable "vpn_clients" {
  type        = list(string)
  description = "Nomes dos clientes roadwarrior (um .conf gerado por nome em ./vpn/)"
  default     = ["erik"]
}

variable "vpn_site_peer_public_key" {
  type        = string
  description = "Chave pública WireGuard do roteador on-premise (vazio = sem site-to-site)"
  default     = ""
}

variable "vpn_site_remote_cidr" {
  type        = string
  description = "CIDR da LAN on-premise atrás do peer site-to-site"
  default     = ""
}

variable "storage_backend" {
  type        = string
  description = "Backend de storage do cluster: longhorn (pve01, legado) ou ceph (Rook-Ceph)"
  default     = "longhorn"
  validation {
    condition     = contains(["longhorn", "ceph"], var.storage_backend)
    error_message = "storage_backend deve ser \"longhorn\" ou \"ceph\"."
  }
}

variable "storage_replicas" {
  type        = number
  description = "Réplicas por volume (Longhorn) ou tamanho do replicated pool (Ceph). Máx = nº de workers"
  default     = 3
}

variable "data_disk_datastore_name" {
  type        = string
  description = "Datastore Proxmox (ZFS) do disco de dados dos workers (Longhorn ou OSD Ceph)"
  default     = "storage"
}

variable "worker_data_disk_size" {
  type        = number
  description = "Tamanho (GB) do disco de dados dos workers (Longhorn). Só cresce."
  default     = 100
}

variable "control_plane_os_disk_size" {
  type        = number
  description = "Tamanho (GB) do disco de SO dos control planes. Só cresce."
  default     = 40
}

variable "worker_os_disk_size" {
  type        = number
  description = "Tamanho (GB) do disco de SO dos workers. Só cresce."
  default     = 30
}

variable "control_plane_cores" {
  type        = number
  description = "vCPUs por control plane."
  default     = 4
}

variable "worker_cores" {
  type        = number
  description = "vCPUs por worker."
  default     = 8
}

variable "control_plane_memory" {
  type        = number
  description = "RAM dedicada (MB) por control plane. Soma de todas as VMs precisa caber na RAM do host com folga para SO + ARC ZFS."
  default     = 8192
}

variable "worker_memory" {
  type        = number
  description = "RAM dedicada (MB) por worker. Mesma regra: sem overcommit no host."
  default     = 16384
}

variable "tunnel_local_port" {
  type        = string
  description = "Porta local do túnel SSH para a API do cluster (16443+; um por servidor)"
  default     = "16443"
}

# ── Versões do Kubernetes/containerd (default = pve01; pve02 sobrescreve) ────

variable "k8s_package_version" {
  type        = string
  description = "Versão dos pacotes apt kubelet/kubeadm/kubectl"
  default     = "1.30.0-1.1"
}

variable "k8s_apt_channel" {
  type        = string
  description = "Canal do repositório apt pkgs.k8s.io (ex: v1.30, v1.35)"
  default     = "v1.30"
}

variable "k8s_kubeadm_api_version" {
  type        = string
  description = "apiVersion do kubeadm-config (kubeadm.k8s.io/vX)"
  default     = "v1beta3"
}

variable "containerd_package_version" {
  type        = string
  description = "Versão do pacote apt containerd.io (sem o sufixo ~ubuntu.24.04~noble)"
  default     = "1.7.27-1"
}

variable "k8s_cluster_version" {
  type        = string
  description = "kubernetesVersion do kubeadm-config (ClusterConfiguration)"
  default     = "v1.30.0"
}

variable "rancher_chart_version" {
  type        = string
  description = "Versão do chart Helm do Rancher (2.13.x recusa k8s >= 1.35; 2.14.x exige >= ... < 1.36)"
  default     = "2.13.3"
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
