variable "proxmox_container_template" {
  type    = string
  default = "local:vztmpl/ct-20240127-nixos-system-x86_64-linux.tar.xz"
}

data "proxmox_virtual_environment_vm" "kubernetes" {
  node_name = "reisen"
  vm_id     = 201
}

resource "proxmox_virtual_environment_container" "reimu" {
  node_name   = "reisen"
  vm_id       = 104
  tags        = ["tf"]
  description = "big hakurei"

  memory {
    dedicated = 512
    swap      = 256
  }

  disk {
    datastore_id = "local-zfs"
    size         = 16
  }

  initialization {
    hostname = "reimu"
    ip_config {
      ipv6 {
        address = "auto"
      }
    }
  }

  network_interface {
    name        = "eth0"
    mac_address = "BC:24:11:C4:66:A8"
  }

  operating_system {
    template_file_id = var.proxmox_container_template
    type             = "nixos"
  }

  unprivileged = true
  features {
    nesting = true
  }

  console {
    type = "console"
  }
  started = false

  lifecycle {
    ignore_changes = [started, description, operating_system[0].template_file_id]
  }
}

resource "terraform_data" "proxmox_reimu_config" {
  depends_on = [
    proxmox_virtual_environment_container.reimu
  ]

  triggers_replace = [
    proxmox_virtual_environment_container.reimu.id
  ]

  connection {
    type     = "ssh"
    user     = var.proxmox_reisen_ssh_username
    password = var.proxmox_reisen_password
    host     = var.proxmox_reisen_ssh_host
    port     = var.proxmox_reisen_ssh_port
  }

  provisioner "remote-exec" {
    inline = [
      "ct-config ${proxmox_virtual_environment_container.reimu.vm_id} unprivileged 0 features 'nesting=1,mount=nfs,mknod=1' lxc.mount.entry '/dev/net/tun dev/net/tun none bind,optional,create=file' lxc.mount.entry '/mnt/kyuuto-media mnt/kyuuto-media none bind,optional,create=dir' lxc.cgroup2.devices.allow 'c 10:200 rwm'",
    ]
  }
}

resource "proxmox_virtual_environment_vm" "freeipa" {
  name        = "freeipa"
  description = "FreeIPA, our identity management system"
  tags        = ["tf"]

  node_name = "reisen"
  vm_id     = 202

  agent {
    # read 'Qemu guest agent' section, change to true only when ready
    enabled = false
  }

  startup {
    order      = "3"
    up_delay   = "60"
    down_delay = "60"
  }

  cdrom {
    enabled = true
    file_id = "local:iso/Fedora-Server-netinst-x86_64-39-1.5.iso"
  }

  memory {
    dedicated = 2048
  }

  disk {
    datastore_id = "local-zfs"
    file_format  = "raw"
    interface    = "scsi0"
    size         = 32
  }

  network_device {
    bridge = "vmbr0"
  }

  operating_system {
    type = "l26"
  }

  tpm_state {
    datastore_id = "local-zfs"
    version      = "v2.0"
  }

  serial_device {}
}
