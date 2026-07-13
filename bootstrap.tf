locals {
  # Host publico extraido do endpoint da API do Proxmox (assume IP no endpoint)
  proxmox_public_host = regex("://([^:/]+)", var.proxmox_endpoint)[0]
  proxmox_ssh_user    = split("@", var.proxmox_user_name)[0]
  control_plane_ip    = format("%s.%s", var.proxmox_network_prefix, var.k8s_control_plane_ip_start)
  ingress_vip         = "${var.proxmox_network_prefix}.100"
  metallb_pool        = "${var.proxmox_network_prefix}.100-${var.proxmox_network_prefix}.110"
}

# Busca kubeconfig (via qm guest exec) e garante tunel 6443. Roda em todo
# apply: e ele que deixa o provider helm funcional nesta maquina.
resource "null_resource" "cluster_access" {
  triggers = {
    always = timestamp()
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/ensure-access.sh"
    environment = {
      PUBLIC_HOST    = local.proxmox_public_host
      CP_IP          = local.control_plane_ip
      SSH_PASSWORD   = var.proxmox_user_password
      KUBECONFIG_OUT = var.kubeconfig_path
      TUNNEL_PORT    = var.tunnel_local_port
    }
  }

  depends_on = [module.proxmox]
}

# DNAT 80/443 do IP publico para o VIP do ingress, direto no host Proxmox.
resource "null_resource" "proxmox_dnat" {
  triggers = {
    public_host = local.proxmox_public_host
    ingress_vip = local.ingress_vip
  }

  connection {
    type     = "ssh"
    host     = local.proxmox_public_host
    user     = local.proxmox_ssh_user
    password = var.proxmox_user_password
    timeout  = "2m"
  }

  provisioner "remote-exec" {
    inline = [
      "sysctl -w net.ipv4.ip_forward=1 >/dev/null",
      "for P in 80 443; do iptables -t nat -C PREROUTING -d ${local.proxmox_public_host} -p tcp --dport $P -j DNAT --to-destination ${local.ingress_vip}:$P 2>/dev/null || iptables -t nat -A PREROUTING -d ${local.proxmox_public_host} -p tcp --dport $P -j DNAT --to-destination ${local.ingress_vip}:$P; done",
      "for P in 80 443; do iptables -C FORWARD -d ${local.ingress_vip} -p tcp --dport $P -j ACCEPT 2>/dev/null || iptables -A FORWARD -d ${local.ingress_vip} -p tcp --dport $P -j ACCEPT; done",
      "command -v netfilter-persistent >/dev/null || DEBIAN_FRONTEND=noninteractive apt-get install -y iptables-persistent",
      "netfilter-persistent save",
    ]
  }
}

# WireGuard no host Proxmox: acesso de clientes e site-to-site com on-premise.
resource "null_resource" "wireguard" {
  count = var.enable_vpn ? 1 : 0

  triggers = {
    public_host = local.proxmox_public_host
    vpn_cidr    = var.vpn_cidr
    clients     = join(",", var.vpn_clients)
    site_peer   = var.vpn_site_peer_public_key
    site_cidr   = var.vpn_site_remote_cidr
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/setup-wireguard.sh"
    environment = {
      PUBLIC_HOST          = local.proxmox_public_host
      SSH_PASSWORD         = var.proxmox_user_password
      VPN_CIDR             = var.vpn_cidr
      VPN_CLIENTS          = join(" ", var.vpn_clients)
      INTERNAL_CIDR        = "${var.proxmox_network_prefix}.0/24"
      SITE_PEER_PUBLIC_KEY = var.vpn_site_peer_public_key
      SITE_REMOTE_CIDR     = var.vpn_site_remote_cidr
    }
  }
}

# Registros A publicos (apex + wildcard) apontando para o host Proxmox.
resource "null_resource" "public_dns" {
  triggers = {
    public_host = local.proxmox_public_host
    domain      = var.domain
  }

  provisioner "local-exec" {
    command = "${path.module}/scripts/update-dns.sh"
    environment = {
      PUBLIC_IP   = local.proxmox_public_host
      GCP_PROJECT = var.gcp_project
      DNS_ZONE    = var.dns_zone
      DOMAIN      = var.domain
      SA_KEY      = var.gcp_sa_key_path
    }
  }
}
