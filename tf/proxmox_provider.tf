variable "proxmox_reisen_endpoint" {
  type = string
}

variable "proxmox_reisen_username" {
  type = string
}

variable "proxmox_reisen_password" {
  type = string
}

variable "proxmox_reisen_ssh_username" {
  type = string
}

variable "proxmox_reisen_ssh_host" {
  type = string
}

variable "proxmox_reisen_ssh_port" {
  type = number
}

provider "proxmox" {
  endpoint = var.proxmox_reisen_endpoint
  username = var.proxmox_reisen_username
  password = var.proxmox_reisen_password

  ssh {
    username = var.proxmox_reisen_ssh_username
    node {
      name    = "reisen"
      address = var.proxmox_reisen_ssh_host
      port    = var.proxmox_reisen_ssh_port
    }
  }
}
