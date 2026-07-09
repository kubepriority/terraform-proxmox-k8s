module "bind9_server" {
  source                 = "./modules/bind9_dnsserver"
  proxmox_endpoint       = var.proxmox_endpoint
  proxmox_user_name      = var.proxmox_user_name
  proxmox_user_password  = var.proxmox_user_password
  proxmox_vm_user        = var.proxmox_vm_user
  proxmox_node_name      = var.proxmox_node_name
  proxmox_datastore_name = var.proxmox_datastore_name
  proxmox_network_bridge = var.proxmox_network_bridge
  proxmox_network_prefix = var.proxmox_network_prefix
  vm_image_id            = module.proxmox.vm_image_id
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

}

module "k8s_addons" {
  source          = "./modules/k8s-addons"
  gcp_sa_key_path = var.gcp_sa_key_path

  depends_on = [module.proxmox]
}
