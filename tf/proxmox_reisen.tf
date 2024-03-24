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

  proxmox_reisen_sysctl_net     = file("${path.root}/../systems/reisen/sysctl.50-net.conf")
  proxmox_reisen_net_vmbr0_ipv6 = file("${path.root}/../systems/reisen/net.50-vmbr0-ipv6.conf")
  proxmox_reisen_udev_dri       = file("${path.root}/../systems/reisen/udev.90-dri.rules")
  proxmox_reisen_udev_z2m       = file("${path.root}/../systems/reisen/udev.90-z2m.rules")

  proxmox_reisen_users = jsondecode(file("${path.root}/../systems/reisen/users.json"))
}

resource "terraform_data" "proxmox_reisen_etc" {
  triggers_replace = [
    local.proxmox_reisen_sysctl_net,
    local.proxmox_reisen_net_vmbr0_ipv6,
    local.proxmox_reisen_udev_dri,
    local.proxmox_reisen_udev_z2m,
  ]

  connection {
    type     = local.proxmox_reisen_connection.type
    user     = local.proxmox_reisen_connection.user
    password = local.proxmox_reisen_connection.password
    host     = local.proxmox_reisen_connection.host
    port     = local.proxmox_reisen_connection.port
  }

  provisioner "remote-exec" {
    inline = [
      "putfile64 /etc/network/interfaces.d/50-vmbr0-ipv6.conf ${base64encode(local.proxmox_reisen_net_vmbr0_ipv6)}",
      "putfile64 /etc/sysctl.d/50-net.conf ${base64encode(local.proxmox_reisen_sysctl_net)}",
      "putfile64 /etc/udev/rules.d/90-dri.rules ${base64encode(local.proxmox_reisen_udev_dri)}",
      "putfile64 /etc/udev/rules.d/90-z2m.rules ${base64encode(local.proxmox_reisen_udev_z2m)}",
    ]
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
