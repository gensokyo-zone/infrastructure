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

data "proxmox_virtual_environment_role" "vm_admin" {
  role_id = "PVEVMAdmin"
}

data "proxmox_virtual_environment_role" "administrator" {
  role_id = "Administrator"
}

resource "proxmox_virtual_environment_group" "admin" {
  group_id = "admin"
  comment  = "System Administrators"

  acl {
    path      = "/"
    propagate = true
    role_id   = data.proxmox_virtual_environment_role.administrator.id
  }
}

resource "random_password" "proxmox_initial" {
  length  = 32
  special = false
}

variable "proxmox_user_arc_email" {
  type = string
}

variable "proxmox_user_arc_first_name" {
  type = string
}

variable "proxmox_user_arc_last_name" {
  type = string
}

resource "proxmox_virtual_environment_user" "arc" {
  user_id    = "arc@pve"
  email      = var.proxmox_user_arc_email
  first_name = var.proxmox_user_arc_first_name
  last_name  = var.proxmox_user_arc_last_name
  password   = random_password.proxmox_initial.result
  groups     = [proxmox_virtual_environment_group.admin.id]

  lifecycle {
    ignore_changes = [password]
  }
}

variable "proxmox_user_kat_email" {
  type = string
}

resource "proxmox_virtual_environment_user" "kat" {
  user_id    = "kat@pve"
  email      = var.proxmox_user_kat_email
  first_name = "Kat"
  last_name  = "Inskip"
  password   = random_password.proxmox_initial.result
  groups     = [proxmox_virtual_environment_group.admin.id]

  lifecycle {
    ignore_changes = [password]
  }
}

variable "proxmox_user_liz_last_name" {
  type = string
}

resource "proxmox_virtual_environment_user" "liz" {
  user_id    = "liz@pve"
  first_name = "Elizabeth"
  last_name  = var.proxmox_user_liz_last_name
  password   = random_password.proxmox_initial.result

  lifecycle {
    ignore_changes = [password]
  }
}
