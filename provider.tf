terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.70.1"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.17"
    }
  }
}

provider "proxmox" {
  endpoint = var.proxmox_endpoint
  password = var.proxmox_user_password
  username = var.proxmox_user_name
  insecure = true
}

provider "helm" {
  kubernetes {
    config_path = var.kubeconfig_path
  }
}
