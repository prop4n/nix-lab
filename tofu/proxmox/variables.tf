variable "pve_endpoint" {
  type        = string
  description = "URL de l'API Proxmox, ex: https://pve.lan:8006/"
}

variable "pve_api_token" {
  type        = string
  sensitive   = true
  description = "Token API Proxmox (user@realm!tokenid=secret)"
}

variable "pve_node" {
  type        = string
  description = "Nom du noeud Proxmox, ex: pve"
}

variable "template_id" {
  type        = number
  description = "VMID du template importe (image-node01, cf. nix build .#packages.x86_64-linux.image-node01)"
}

variable "node01_age_key" {
  type        = string
  sensitive   = true
  description = "Contenu de keys/node01.age (cle age privee pour sops-nix)"
}
