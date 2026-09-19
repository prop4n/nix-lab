terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.66"
    }
  }
}

provider "proxmox" {
  endpoint  = var.pve_endpoint
  api_token = var.pve_api_token
  insecure  = true

  # L'upload des snippets (cloud-init user-data) passe par SSH/SFTP sur le node,
  # pas par l'API. Par défaut on utilise l'agent SSH ; sinon renseigner
  # pve_ssh_private_key dans terraform.tfvars.
  ssh {
    username    = var.pve_ssh_username
    password    = var.pve_ssh_password == "" ? null : var.pve_ssh_password
    private_key = var.pve_ssh_private_key == "" ? null : var.pve_ssh_private_key
    agent       = var.pve_ssh_password == "" && var.pve_ssh_private_key == ""

    # Force le SSH vers l'IP de l'endpoint (la ou tu joins reellement le PVE),
    # au lieu de l'adresse que l'API rapporte pour le node (souvent injoignable).
    node {
      name    = var.pve_node
      address = local.pve_host
    }
  }
}

locals {
  pve_host = regex("^https?://([^:/]+)", var.pve_endpoint)[0]
}

resource "proxmox_virtual_environment_file" "node01_ci" {
  content_type = "snippets"
  datastore_id = "local"
  node_name    = var.pve_node

  source_raw {
    file_name = "cloud-init-node01.yaml"
    data = templatefile("${path.module}/cloud-init-node01.yaml.tftpl", {
      age_key = var.node01_age_key
    })
  }
}

resource "proxmox_virtual_environment_vm" "node01" {
  name      = "node01"
  node_name = var.pve_node

  clone {
    vm_id = var.template_id
  }

  cpu {
    cores = 2
  }

  memory {
    dedicated = 2048
  }

  agent {
    enabled = true
  }

  network_device {
    bridge = "vmbr0"
  }

  initialization {
    datastore_id      = "local-lvm"
    user_data_file_id = proxmox_virtual_environment_file.node01_ci.id

    ip_config {
      ipv4 {
        address = var.node01_ip
        gateway = var.node01_ip == "dhcp" ? null : var.node01_gateway
      }
    }
  }
}
