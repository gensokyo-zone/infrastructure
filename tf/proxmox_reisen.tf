locals {
  proxmox_reisen_connection = {
    type     = "ssh"
    user     = var.proxmox_reisen_ssh_username
    password = var.proxmox_reisen_password
    host     = var.proxmox_reisen_ssh_host
    port     = var.proxmox_reisen_ssh_port
  }

  proxmox_reisen_sysctl_net = file("${path.root}/../systems/reisen/sysctl.50-net.conf")
  proxmox_reisen_udev_dri   = file("${path.root}/../systems/reisen/udev.90-dri.rules")
  proxmox_reisen_udev_z2m   = file("${path.root}/../systems/reisen/udev.90-z2m.rules")
}

resource "terraform_data" "proxmox_reisen_etc" {
  triggers_replace = [
    local.proxmox_reisen_sysctl_net,
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
      "putfile64 /etc/sysctl.d/50-net.conf ${base64encode(local.proxmox_reisen_sysctl_net)}",
      "putfile64 /etc/udev/rules.d/90-dri.rules ${base64encode(local.proxmox_reisen_udev_dri)}",
      "putfile64 /etc/udev/rules.d/90-z2m.rules ${base64encode(local.proxmox_reisen_udev_z2m)}",
    ]
  }
}
