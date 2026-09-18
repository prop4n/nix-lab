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
        address = "dhcp"
      }
    }
  }
}
