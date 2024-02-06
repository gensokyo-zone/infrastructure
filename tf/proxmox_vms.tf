variable "proxmox_container_template" {
  type    = string
  default = "local:vztmpl/ct-20240127-nixos-system-x86_64-linux.tar.xz"
}

locals {
  proxmox_reimu_vm_id      = 104
  proxmox_reimu_config     = jsondecode(file("${path.root}/../systems/reimu/lxc.json"))
  proxmox_hakurei_vm_id    = 103
  proxmox_hakurei_config   = jsondecode(file("${path.root}/../systems/hakurei/lxc.json"))
  proxmox_tei_vm_id        = 101
  proxmox_tei_config       = jsondecode(file("${path.root}/../systems/tei/lxc.json"))
  proxmox_mediabox_vm_id   = 102
  proxmox_mediabox_config  = jsondecode(file("${path.root}/../systems/mediabox/lxc.json"))
  proxmox_kubernetes_vm_id = 201
  proxmox_freeipa_vm_id    = 202
}

data "proxmox_virtual_environment_vm" "kubernetes" {
  node_name = "reisen"
  vm_id     = local.proxmox_kubernetes_vm_id
}

module "hakurei_config" {
  source     = "./system/proxmox/lxc/config"
  connection = local.proxmox_reisen_connection
  vm_id      = local.proxmox_hakurei_vm_id
  config     = local.proxmox_hakurei_config.lxc
}

module "tei_config" {
  source     = "./system/proxmox/lxc/config"
  connection = local.proxmox_reisen_connection
  vm_id      = local.proxmox_tei_vm_id
  config     = local.proxmox_tei_config.lxc
}

module "mediabox_config" {
  source     = "./system/proxmox/lxc/config"
  connection = local.proxmox_reisen_connection
  vm_id      = local.proxmox_mediabox_vm_id
  config     = local.proxmox_mediabox_config.lxc
}

resource "proxmox_virtual_environment_container" "reimu" {
  node_name   = "reisen"
  vm_id       = local.proxmox_reimu_vm_id
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

module "reimu_config" {
  source     = "./system/proxmox/lxc/config"
  connection = local.proxmox_reisen_connection
  container  = proxmox_virtual_environment_container.reimu
  config     = local.proxmox_reimu_config.lxc
}

resource "proxmox_virtual_environment_vm" "freeipa" {
  name        = "freeipa"
  description = "FreeIPA, our identity management system"
  tags        = ["tf"]

  node_name = "reisen"
  vm_id     = local.proxmox_freeipa_vm_id

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

  lifecycle {
    ignore_changes = [started, operating_system[0], cdrom[0].enabled, cdrom[0].file_id]
  }
}
