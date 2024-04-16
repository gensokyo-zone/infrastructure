locals {
  reisen_int_prefix4 = "10.9.1.0/24"
  reisen_int_prefix6 = "fd0c::/64"
  reisen_int_offset  = 32

  proxmox_reisen_connection = {
    type     = "ssh"
    user     = var.proxmox_reisen_ssh_username
    password = var.proxmox_reisen_password
    host     = var.proxmox_reisen_ssh_host
    port     = var.proxmox_reisen_ssh_port
  }

  proxmox_reisen_users   = jsondecode(file("${path.root}/../systems/reisen/users.json"))
  proxmox_reisen_systems = jsondecode(file("${path.root}/../systems/reisen/systems.json"))
  proxmox_reisen_extern  = jsondecode(file("${path.root}/../systems/reisen/extern.json"))

  proxmox_reisen_files = [
    for dest, file in local.proxmox_reisen_extern.files : merge(
      file,
      {
        dest = dest
        path = "${path.root}/../${file.source}"
      }
    )
  ]

  systems = jsondecode(file("${path.root}/../ci/systems.json"))
}

resource "terraform_data" "proxmox_reisen_etc" {
  triggers_replace = [for file in local.proxmox_reisen_files : {
    dest  = file.dest
    sh256 = filesha256(file.path)
  }]

  connection {
    type     = local.proxmox_reisen_connection.type
    user     = local.proxmox_reisen_connection.user
    password = local.proxmox_reisen_connection.password
    host     = local.proxmox_reisen_connection.host
    port     = local.proxmox_reisen_connection.port
  }

  provisioner "remote-exec" {
    inline = [for file in local.proxmox_reisen_files : "putfile64 ${file.dest} ${filebase64(file.path)}"]
  }
}

resource "terraform_data" "proxmox_reisen_users" {
  triggers_replace = {
    users = local.proxmox_reisen_users
  }

  connection {
    type     = local.proxmox_reisen_connection.type
    user     = local.proxmox_reisen_connection.user
    password = local.proxmox_reisen_connection.password
    host     = local.proxmox_reisen_connection.host
    port     = local.proxmox_reisen_connection.port
  }

  provisioner "remote-exec" {
    inline = [for user in local.proxmox_reisen_users :
      "mkpam '${user.name}' '${user.uid}'"
    ]
  }
}

resource "proxmox_virtual_environment_network_linux_bridge" "internal" {
  node_name = "reisen"
  name      = "vmbr9"
  address   = "${cidrhost(local.reisen_int_prefix4, 2)}/24"
  address6  = "${cidrhost(local.reisen_int_prefix6, 2)}/64"
  comment   = "internal private network"
}
