variable "proxmox_reisen_endpoint" {
  type = string
}

variable "proxmox_reisen_username" {
  type = string
}

variable "proxmox_reisen_password" {
  type = string
  sensitive = true
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

data "proxmox_virtual_environment_role" "vm_user" {
  role_id = "PVEVMUser"
}

data "proxmox_virtual_environment_role" "auditor" {
  role_id = "PVEAuditor"
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

resource "proxmox_virtual_environment_group" "user" {
  group_id = "user"
  comment  = "Users"

  acl {
    path      = "/"
    propagate = true
    role_id   = data.proxmox_virtual_environment_role.auditor.id
  }
  acl {
    path      = "/"
    propagate = true
    role_id   = data.proxmox_virtual_environment_role.vm_user.id
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
  user_id    = "arc@pam"
  email      = var.proxmox_user_arc_email
  first_name = var.proxmox_user_arc_first_name
  last_name  = var.proxmox_user_arc_last_name
  password   = random_password.proxmox_initial.result
  groups     = [proxmox_virtual_environment_group.admin.id]

  lifecycle {
    ignore_changes = [password]
  }

  depends_on = [
    terraform_data.proxmox_reisen_users,
  ]
}

variable "proxmox_user_kat_email" {
  type = string
}

resource "proxmox_virtual_environment_user" "kat" {
  user_id    = "kat@pam"
  email      = var.proxmox_user_kat_email
  first_name = "Kat"
  last_name  = "Inskip"
  password   = random_password.proxmox_initial.result
  groups     = [proxmox_virtual_environment_group.admin.id]

  lifecycle {
    ignore_changes = [password]
  }

  depends_on = [
    terraform_data.proxmox_reisen_users,
  ]
}

variable "proxmox_user_kaosubaloo_email" {
  type = string
}

variable "proxmox_user_kaosubaloo_first_name" {
  type = string
}

variable "proxmox_user_kaosubaloo_last_name" {
  type = string
}

resource "proxmox_virtual_environment_user" "kaosubaloo" {
  user_id    = "kaosubaloo@pam"
  email      = var.proxmox_user_kaosubaloo_email
  first_name = var.proxmox_user_kaosubaloo_first_name
  last_name  = var.proxmox_user_kaosubaloo_last_name
  password   = random_password.proxmox_initial.result
  groups     = [proxmox_virtual_environment_group.user.id]

  lifecycle {
    ignore_changes = [password]
  }
}

variable "proxmox_user_connieallure_email" {
  type = string
}

variable "proxmox_user_connieallure_last_name" {
  type = string
}

resource "proxmox_virtual_environment_user" "connieallure" {
  user_id    = "connieallure@pam"
  email      = var.proxmox_user_connieallure_email
  first_name = "Connie"
  last_name  = var.proxmox_user_connieallure_last_name
  password   = random_password.proxmox_initial.result
  groups     = [proxmox_virtual_environment_group.user.id]

  lifecycle {
    ignore_changes = [password]
  }

  depends_on = [
    terraform_data.proxmox_reisen_users,
  ]
}
