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

variable "proxmox_node_name" {
  description = "Proxmox server name"
  type        = string
}

variable "proxmox_vm_name_k8s_worker_node" {
  description = "k8s worker node name"
  type        = string
  default     = "k8s-worker-"
}

variable "proxmox_vm_name_k8s_control_plane" {
  description = "k8s control plane name"
  type        = string
  default     = "k8s-control-plane-"
}

variable "proxmox_number_of_vm_k8s_worker_node" {
  description = "Number of k8s worker nodes"
  type        = string
}

variable "proxmox_number_of_vm_k8s_control_plane" {
  description = "Number of k8s control plane nodes"
  type        = string
}

variable "k8s_control_plane_ip_start" {
  description = "First IP of the k8s control plane address range"
  type        = string
}

variable "k8s_worker_ip_start" {
  description = "First IP of the k8s worker nodes address range"
  type        = string
}

variable "proxmox_datastore_name" {
  description = "Promox datastore para snippets e imagens (precisa aceitar iso/snippets)"
  type        = string
  default     = "local"
}

variable "proxmox_vm_datastore_name" {
  description = "Datastore dos discos das VMs"
  type        = string
  default     = "data"
}

variable "data_disk_datastore_name" {
  description = "Datastore do disco de dados dos workers (Longhorn ou OSD Ceph)"
  type        = string
  default     = "storage"
}

variable "storage_backend" {
  type        = string
  description = "longhorn: formata/monta /dev/vdb no cloud-init; ceph: deixa vdb raw para OSD"
}

variable "proxmox_network_bridge" {
  description = "Proxmox network bridge for VM NICs"
  type        = string
}

variable "proxmox_network_prefix" {
  description = "First three octets of the VM network (e.g. 10.10.10)"
  type        = string
}
variable "worker_data_disk_size" {
  type        = number
  description = "Tamanho (GB) do disco de dados dos workers (usado pelo Longhorn). Só cresce — diminuir força recriar a VM."
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
  description = "RAM dedicada (MB) por control plane. Soma de todas as VMs deve caber na RAM do host com folga para SO + ARC do ZFS — overcommit derruba VM via OOM killer."
  default     = 8192
}

variable "worker_memory" {
  type        = number
  description = "RAM dedicada (MB) por worker. Mesma regra: sem overcommit no host."
  default     = 16384
}

variable "vm_image_id" {
  description = "Ubuntu cloud image id (recurso criado no root)"
  type        = string
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
