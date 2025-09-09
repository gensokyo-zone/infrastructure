locals {
  meiling_int_prefix4 = "10.9.2.0/24"
  meiling_int_prefix6 = "fd0c:0:0:2::/64"
  meiling_int_offset  = 32
  meiling_int_addr4   = local.systems.meiling.network.networks.int.address4
  #meiling_int_bridge = proxmox_virtual_environment_network_linux_bridge.meiling_internal.name
  meiling_int_bridge  = "vmbr9"

  proxmox_meiling_connection = {
    type     = "ssh"
    user     = var.proxmox_meiling_ssh_username
    password = var.proxmox_meiling_password
    host     = var.proxmox_meiling_ssh_host
    port     = var.proxmox_meiling_ssh_port
  }

  proxmox_meiling_users   = jsondecode(file("${path.root}/../systems/meiling/users.json"))
  proxmox_meiling_systems = jsondecode(file("${path.root}/../systems/meiling/systems.json"))
  proxmox_meiling_extern  = jsondecode(file("${path.root}/../systems/meiling/extern.json"))

  proxmox_meiling_files = [
    for dest, file in local.proxmox_meiling_extern.files : merge(
      file,
      {
        dest = dest
        path = "${path.root}/../${file.source}"
      }
    )
  ]
}

variable "proxmox_meiling_endpoint" {
  type = string
}

variable "proxmox_meiling_username" {
  type = string
}

variable "proxmox_meiling_password" {
  type = string
  sensitive = true
}

variable "proxmox_meiling_ssh_username" {
  type = string
}

variable "proxmox_meiling_ssh_host" {
  type = string
}

variable "proxmox_meiling_ssh_port" {
  type = number
}

provider "proxmox" {
  alias = "meiling"
  endpoint = var.proxmox_meiling_endpoint
  username = var.proxmox_meiling_username
  password = var.proxmox_meiling_password

  ssh {
    username = var.proxmox_meiling_ssh_username
    node {
      name    = "meiling"
      address = var.proxmox_meiling_ssh_host
      port    = var.proxmox_meiling_ssh_port
    }
  }
}

resource "terraform_data" "proxmox_meiling_etc" {
  triggers_replace = [for file in local.proxmox_meiling_files : {
    dest  = file.dest
    sh256 = filesha256(file.path)
  }]

  connection {
    type     = local.proxmox_meiling_connection.type
    user     = local.proxmox_meiling_connection.user
    password = local.proxmox_meiling_connection.password
    host     = local.proxmox_meiling_connection.host
    port     = local.proxmox_meiling_connection.port
  }

  provisioner "remote-exec" {
    inline = [for file in local.proxmox_meiling_files : "putfile64 ${file.dest} ${filebase64(file.path)}"]
  }
}

resource "terraform_data" "proxmox_meiling_users" {
  triggers_replace = {
    users = local.proxmox_meiling_users
  }

  connection {
    type     = local.proxmox_meiling_connection.type
    user     = local.proxmox_meiling_connection.user
    password = local.proxmox_meiling_connection.password
    host     = local.proxmox_meiling_connection.host
    port     = local.proxmox_meiling_connection.port
  }

  provisioner "remote-exec" {
    inline = [for user in local.proxmox_meiling_users :
      "mkpam '${user.name}' '${user.uid}'"
    ]
  }
}

# datasource "proxmox_virtual_environment_network_linux_bridge" "meiling_internal" ?
