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

variable "pve_ssh_username" {
  type        = string
  default     = "root"
  description = "Utilisateur SSH sur le node PVE (upload des snippets cloud-init)"
}

variable "pve_ssh_private_key" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Cle privee SSH pour le node PVE. Vide => agent SSH."
}

variable "pve_ssh_password" {
  type        = string
  sensitive   = true
  default     = ""
  description = "Mot de passe SSH du node PVE (si tu te connectes en mdp). Prioritaire sur l'agent."
}

variable "node01_ip" {
  type        = string
  default     = "dhcp"
  description = "IP de node01 en CIDR (ex: 192.168.1.201/24), ou 'dhcp'."
}

variable "node01_gateway" {
  type        = string
  default     = ""
  description = "Passerelle de node01 (ex: 192.168.1.1), requise si IP statique."
}
