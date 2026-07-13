# Cloud-init canonico (renderizado do template), usado por todas as VMs k8s.
resource "proxmox_virtual_environment_file" "k8s_cloud_config_ha" {
  content_type = "snippets"
  datastore_id = var.proxmox_datastore_name
  node_name    = var.proxmox_node_name

  source_raw {
    data = templatefile("${path.module}/templates/cloud-config.yaml.tftpl", {
      proxmox_network_prefix                 = var.proxmox_network_prefix
      k8s_control_plane_ip_start             = var.k8s_control_plane_ip_start
      k8s_worker_ip_start                    = var.k8s_worker_ip_start
      proxmox_number_of_vm_k8s_control_plane = var.proxmox_number_of_vm_k8s_control_plane
      proxmox_number_of_vm_k8s_worker_node   = var.proxmox_number_of_vm_k8s_worker_node
      proxmox_vm_name_k8s_control_plane      = var.proxmox_vm_name_k8s_control_plane
      proxmox_vm_name_k8s_worker_node        = var.proxmox_vm_name_k8s_worker_node
      proxmox_vm_user                        = var.proxmox_vm_user
      ssh_public_key                         = trimspace(data.local_file.ssh_public_key.content)
    })

    file_name = "cloud-config-ha.yaml"
  }
}

# Existing Kubernetes Control Plane VMs
resource "proxmox_virtual_environment_vm" "k8s-control-plane" {
  count           = var.proxmox_number_of_vm_k8s_control_plane
  name            = format("%s%s", var.proxmox_vm_name_k8s_control_plane, count.index)
  node_name       = var.proxmox_node_name
  stop_on_destroy = true

  agent {
    enabled = true
  }

  initialization {
    datastore_id = var.proxmox_vm_datastore_name
    user_data_file_id = proxmox_virtual_environment_file.k8s_cloud_config_ha.id

    ip_config {
      ipv4 {
        address = format("%s.%d/24", var.proxmox_network_prefix, count.index + var.k8s_control_plane_ip_start)
        gateway = "${var.proxmox_network_prefix}.1"
      }
    }
  }

  disk {
    datastore_id = var.proxmox_vm_datastore_name
    file_format  = "raw"
    file_id      = var.vm_image_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 40
  }

  cpu {
    architecture = "x86_64"
    cores        = 4
    type         = "host"
  }

  memory {
    dedicated = 8192
  }

  network_device {
    bridge = var.proxmox_network_bridge
  }

  # Mudanca no template cloud-init NAO pode recriar control planes vivos:
  # destruir 2 CPs juntos derruba o quorum do etcd. VM nova (count maior)
  # nasce com o template atual; VM existente ignora o novo user_data.
  # Recriar de proposito: -replace=... UM POR VEZ, removendo antes o no
  # (kubectl delete node) para o etcd nao ficar com membro morto.
  lifecycle {
    ignore_changes = [initialization]
  }

  depends_on = [proxmox_virtual_environment_file.k8s_cloud_config_ha]
}

# Existing Kubernetes Worker Nodes
resource "proxmox_virtual_environment_vm" "k8s-worker-node" {
  count           = var.proxmox_number_of_vm_k8s_worker_node
  name            = format("%s%s", var.proxmox_vm_name_k8s_worker_node, count.index)
  node_name       = var.proxmox_node_name
  stop_on_destroy = true

  agent {
    enabled = true
  }

  initialization {
    datastore_id      = var.proxmox_vm_datastore_name
    user_data_file_id = proxmox_virtual_environment_file.k8s_cloud_config_ha.id

    ip_config {
      ipv4 {
        address = format("%s.%d/24", var.proxmox_network_prefix, count.index + var.k8s_worker_ip_start)
        gateway = "${var.proxmox_network_prefix}.1"
      }
    }
  }

  disk {
    datastore_id = var.proxmox_vm_datastore_name
    file_format  = "raw"
    file_id      = var.vm_image_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = 30
  }

  disk {
    datastore_id = var.longhorn_datastore_name
    file_format  = "raw"
    interface    = "virtio1"
    iothread     = true
    discard      = "on"
    size         = var.worker_data_disk_size
  }

  cpu {
    architecture = "x86_64"
    cores        = 8
    type         = "host"
  }

  memory {
    dedicated = 16384
  }

  network_device {
    bridge = var.proxmox_network_bridge
  }

  # Mesma protecao dos control planes: recriar workers em massa destroi as
  # replicas do Longhorn. Recriar de proposito: -replace UM POR VEZ com
  # drain + delete node antes.
  lifecycle {
    ignore_changes = [initialization]
  }

  depends_on = [proxmox_virtual_environment_vm.k8s-control-plane]
}


# SSH Public Key
data "local_file" "ssh_public_key" {
  filename = "./id_rsa.pub"
}

#TODO: Prepare one node to be the "IA node"
#TODO: https://hub.docker.com/r/ollama/ollama