# Imagem Ubuntu no root: bind9 e as VMs k8s dependem dela sem criar ciclo
# entre os modulos (k8s depende do bind9 operacional via depends_on abaixo).
resource "proxmox_virtual_environment_download_file" "ubuntu_cloud_image" {
  content_type   = "iso"
  datastore_id   = var.proxmox_datastore_name
  node_name      = var.proxmox_node_name
  upload_timeout = 2500

  url = "https://cloud-images.ubuntu.com/releases/24.04/release/ubuntu-24.04-server-cloudimg-amd64.img"
}

module "bind9_server" {
  source                 = "./modules/bind9_dnsserver"
  proxmox_endpoint       = var.proxmox_endpoint
  proxmox_user_name      = var.proxmox_user_name
  proxmox_user_password  = var.proxmox_user_password
  proxmox_vm_user        = var.proxmox_vm_user
  proxmox_node_name      = var.proxmox_node_name
  proxmox_datastore_name = var.proxmox_datastore_name
  proxmox_vm_datastore_name = var.proxmox_vm_datastore_name
  proxmox_network_bridge = var.proxmox_network_bridge
  proxmox_network_prefix = var.proxmox_network_prefix
  vm_image_id            = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
}

module "proxmox" {
  source                                 = "./modules/proxmox"
  proxmox_endpoint                       = var.proxmox_endpoint
  proxmox_vm_password                    = var.proxmox_vm_password
  proxmox_user_name                      = var.proxmox_user_name
  proxmox_user_password                  = var.proxmox_user_password
  proxmox_vm_user                        = var.proxmox_vm_user
  k8s_control_plane_ip_start             = var.k8s_control_plane_ip_start
  k8s_worker_ip_start                    = var.k8s_worker_ip_start
  proxmox_number_of_vm_k8s_control_plane = var.proxmox_number_of_vm_k8s_control_plane
  proxmox_number_of_vm_k8s_worker_node   = var.proxmox_number_of_vm_k8s_worker_node
  proxmox_node_name                      = var.proxmox_node_name
  proxmox_network_bridge                 = var.proxmox_network_bridge
  proxmox_network_prefix                 = var.proxmox_network_prefix
  worker_data_disk_size                  = var.worker_data_disk_size
  control_plane_os_disk_size             = var.control_plane_os_disk_size
  worker_os_disk_size                    = var.worker_os_disk_size
  control_plane_cores                    = var.control_plane_cores
  worker_cores                           = var.worker_cores
  control_plane_memory                   = var.control_plane_memory
  worker_memory                          = var.worker_memory
  proxmox_datastore_name                 = var.proxmox_datastore_name
  proxmox_vm_datastore_name              = var.proxmox_vm_datastore_name
  data_disk_datastore_name               = var.data_disk_datastore_name
  storage_backend                        = var.storage_backend
  vm_image_id                            = proxmox_virtual_environment_download_file.ubuntu_cloud_image.id
  k8s_package_version                    = var.k8s_package_version
  k8s_apt_channel                        = var.k8s_apt_channel
  k8s_kubeadm_api_version                = var.k8s_kubeadm_api_version
  containerd_package_version             = var.containerd_package_version
  k8s_cluster_version                    = var.k8s_cluster_version

  # kubeadm precisa do DNS (bind9) resolvendo antes das VMs k8s bootarem.
  # O guest agent do bind9 so inicia no fim do cloud-init dele, entao a
  # criacao da VM bind9 (que espera o agent) e o gate de "DNS operacional".
  depends_on = [module.bind9_server]
}

module "k8s_addons" {
  source                     = "./modules/k8s-addons"
  gcp_sa_key_path            = var.gcp_sa_key_path
  rancher_bootstrap_password = var.rancher_bootstrap_password
  domain                     = var.domain
  gcp_project                = var.gcp_project
  metallb_pool               = local.metallb_pool
  ingress_vip                = local.ingress_vip
  rancher_hostname           = "rancher.${var.domain}"
  argocd_hostname            = "argocd.${var.domain}"
  passbolt_hostname          = "passbolt.${var.domain}"
  enable_rancher             = var.enable_rancher
  enable_metrics_server      = var.enable_metrics_server
  enable_argocd              = var.enable_argocd
  enable_passbolt            = var.enable_passbolt
  storage_backend            = var.storage_backend
  storage_replicas           = var.storage_replicas
  rancher_chart_version      = var.rancher_chart_version

  depends_on = [module.proxmox, null_resource.cluster_access]
}
