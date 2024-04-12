variable "proxmox_container_template" {
  type    = string
  default = "local:vztmpl/ct-20240408-nixos-system-x86_64-linux.tar.xz"
}

locals {
  proxmox_utsuho_vm_id     = 108
  proxmox_utsuho_config    = jsondecode(file("${path.root}/../systems/utsuho/lxc.json"))
  proxmox_keycloak_vm_id   = 107
  proxmox_keycloak_config  = jsondecode(file("${path.root}/../systems/keycloak/lxc.json"))
  proxmox_litterbox_vm_id  = 106
  proxmox_litterbox_config = jsondecode(file("${path.root}/../systems/litterbox/lxc.json"))
  proxmox_aya_vm_id        = 105
  proxmox_aya_config       = jsondecode(file("${path.root}/../systems/aya/lxc.json"))
  proxmox_reimu_vm_id      = 104
  proxmox_reimu_config     = jsondecode(file("${path.root}/../systems/reimu/lxc.json"))
  proxmox_hakurei_vm_id    = 103
  proxmox_hakurei_config   = jsondecode(file("${path.root}/../systems/hakurei/lxc.json"))
  proxmox_tewi_vm_id       = 101
  proxmox_tewi_config      = jsondecode(file("${path.root}/../systems/tei/lxc.json"))
  proxmox_mediabox_vm_id   = 102
  proxmox_mediabox_config  = jsondecode(file("${path.root}/../systems/mediabox/lxc.json"))
  proxmox_kubernetes_vm_id = 201
  proxmox_freeipa_vm_id    = 202
  proxmox_freepbx_vm_id    = 203
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

resource "proxmox_virtual_environment_container" "tewi" {
  node_name   = "reisen"
  vm_id       = local.proxmox_tewi_vm_id
  tags        = ["tf"]
  description = <<EOT
tewi
EOT

  memory {
    dedicated = 2048
    swap      = 4096
  }

  cpu {
    cores = 2
  }

  disk {
    datastore_id = "local-zfs"
    size         = 32
  }

  initialization {
    hostname = "tei"
    ip_config {
      ipv6 {
        address = "auto"
      }
      ipv4 {
        address = "10.1.1.39/24"
        gateway = "10.1.1.1"
      }
    }
    ip_config {
      ipv6 {
        address = "${cidrhost(local.reisen_int_prefix6, local.proxmox_tewi_vm_id - local.reisen_int_offset)}/64"
      }
      ipv4 {
        address = "${cidrhost(local.reisen_int_prefix4, local.proxmox_tewi_vm_id - local.reisen_int_offset)}/24"
      }
    }
  }

  startup {
    order      = 16
    up_delay   = 0
    down_delay = 8
  }

  network_interface {
    name        = "eth0"
    mac_address = "BC:24:11:CC:66:57"
  }
  network_interface {
    name        = "eth9"
    mac_address = "BC:24:19:CC:66:57"
    bridge      = proxmox_virtual_environment_network_linux_bridge.internal.name
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
    ignore_changes = [started, initialization[0].dns, operating_system[0].template_file_id]
  }
}

module "tewi_config" {
  source     = "./system/proxmox/lxc/config"
  connection = local.proxmox_reisen_connection
  container  = proxmox_virtual_environment_container.tewi
  config     = local.proxmox_tewi_config.lxc
}

resource "proxmox_virtual_environment_container" "mediabox" {
  node_name   = "reisen"
  vm_id       = local.proxmox_mediabox_vm_id
  tags        = ["tf"]
  description = <<EOT
plex
EOT

  memory {
    dedicated = 8192
    swap      = 4096
  }

  cpu {
    cores = 8
  }

  disk {
    datastore_id = "local-zfs"
    size         = 30
  }

  initialization {
    hostname = "mediabox"
    ip_config {
      ipv6 {
        address = "auto"
      }
      ipv4 {
        address = "10.1.1.44/24"
        gateway = "10.1.1.1"
      }
    }
    ip_config {
      ipv6 {
        address = "${cidrhost(local.reisen_int_prefix6, local.proxmox_mediabox_vm_id - local.reisen_int_offset)}/64"
      }
      ipv4 {
        address = "${cidrhost(local.reisen_int_prefix4, local.proxmox_mediabox_vm_id - local.reisen_int_offset)}/24"
      }
    }
  }

  startup {
    order      = 32
    up_delay   = 0
    down_delay = 4
  }

  network_interface {
    name        = "eth0"
    mac_address = "BC:24:11:34:F4:A8"
  }
  network_interface {
    name        = "eth9"
    mac_address = "BC:24:19:34:F4:A8"
    bridge      = proxmox_virtual_environment_network_linux_bridge.internal.name
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
    ignore_changes = [started, initialization[0].dns, operating_system[0].template_file_id]
  }
}

module "mediabox_config" {
  source     = "./system/proxmox/lxc/config"
  connection = local.proxmox_reisen_connection
  container  = proxmox_virtual_environment_container.mediabox
  config     = local.proxmox_mediabox_config.lxc
}

resource "proxmox_virtual_environment_container" "reimu" {
  node_name   = "reisen"
  vm_id       = local.proxmox_reimu_vm_id
  tags        = ["tf"]
  description = <<EOT
big hakurei
EOT

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
      ipv4 {
        address = "10.1.1.45/24"
        gateway = "10.1.1.1"
      }
    }
    ip_config {
      ipv6 {
        address = "${cidrhost(local.reisen_int_prefix6, local.proxmox_reimu_vm_id - local.reisen_int_offset)}/64"
      }
      ipv4 {
        address = "${cidrhost(local.reisen_int_prefix4, local.proxmox_reimu_vm_id - local.reisen_int_offset)}/24"
      }
    }
  }

  startup {
    order      = 4
    up_delay   = 0
    down_delay = 0
  }

  network_interface {
    name        = "eth0"
    mac_address = "BC:24:11:C4:66:A8"
  }
  network_interface {
    name        = "eth9"
    mac_address = "BC:24:19:C4:66:A8"
    bridge      = proxmox_virtual_environment_network_linux_bridge.internal.name
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
    ignore_changes = [started, unprivileged, initialization[0].dns, operating_system[0].template_file_id]
  }
}

module "reimu_config" {
  source     = "./system/proxmox/lxc/config"
  connection = local.proxmox_reisen_connection
  container  = proxmox_virtual_environment_container.reimu
  config     = local.proxmox_reimu_config.lxc
}

resource "proxmox_virtual_environment_container" "aya" {
  node_name   = "reisen"
  vm_id       = local.proxmox_aya_vm_id
  tags        = ["tf"]
  description = <<EOT
zoomzoom
EOT

  memory {
    dedicated = 16384
    swap      = 12288
  }

  cpu {
    cores = 12
    units = 768
  }

  disk {
    datastore_id = "local-zfs"
    size         = 32
  }

  initialization {
    hostname = "aya"
    ip_config {
      ipv6 {
        address = "auto"
      }
      ipv4 {
        address = "10.1.1.47/24"
        gateway = "10.1.1.1"
      }
    }
    ip_config {
      ipv6 {
        address = "${cidrhost(local.reisen_int_prefix6, local.proxmox_aya_vm_id - local.reisen_int_offset)}/64"
      }
      ipv4 {
        address = "${cidrhost(local.reisen_int_prefix4, local.proxmox_aya_vm_id - local.reisen_int_offset)}/24"
      }
    }
    # empty block causes state sync issues
    #ip_config {}
  }

  startup {
    order      = 4
    up_delay   = 0
    down_delay = 0
  }

  network_interface {
    name        = "eth0"
    mac_address = "BC:24:11:C4:66:A9"
  }
  network_interface {
    name        = "eth9"
    mac_address = "BC:24:19:C4:66:A9"
    bridge      = proxmox_virtual_environment_network_linux_bridge.internal.name
  }
  network_interface {
    name        = "eth1"
    mac_address = "BC:24:11:C4:66:AA"
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
    ignore_changes = [started, initialization[0].dns, operating_system[0].template_file_id]
  }
}

module "aya_config" {
  source     = "./system/proxmox/lxc/config"
  connection = local.proxmox_reisen_connection
  container  = proxmox_virtual_environment_container.aya
  config     = local.proxmox_aya_config.lxc
}

resource "proxmox_virtual_environment_container" "utsuho" {
  node_name   = "reisen"
  vm_id       = local.proxmox_utsuho_vm_id
  tags        = ["tf"]
  description = <<EOT
zoomzoom
EOT

  memory {
    dedicated = 2048
    swap      = 4096
  }

  cpu {
    cores = 2
  }

  disk {
    datastore_id = "local-zfs"
    size         = 32
  }

  initialization {
    hostname = "utsuho"
    ip_config {
      ipv6 {
        address = "auto"
      }
      ipv4 {
        address = "10.1.1.38/24"
        gateway = "10.1.1.1"
      }
    }
    ip_config {
      ipv6 {
        address = "${cidrhost(local.reisen_int_prefix6, local.proxmox_utsuho_vm_id - local.reisen_int_offset)}/64"
      }
      ipv4 {
        address = "${cidrhost(local.reisen_int_prefix4, local.proxmox_utsuho_vm_id - local.reisen_int_offset)}/24"
      }
    }
  }

  startup {
    order      = 4
    up_delay   = 0
    down_delay = 2
  }

  network_interface {
    name        = "eth0"
    mac_address = "BC:24:11:C4:66:A6"
  }
  network_interface {
    name        = "eth9"
    mac_address = "BC:24:19:C4:66:A6"
    bridge      = proxmox_virtual_environment_network_linux_bridge.internal.name
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
    ignore_changes = [started, initialization[0].dns, operating_system[0].template_file_id]
  }
}

module "utsuho_config" {
  source     = "./system/proxmox/lxc/config"
  connection = local.proxmox_reisen_connection
  container  = proxmox_virtual_environment_container.utsuho
  config     = local.proxmox_utsuho_config.lxc
}

resource "proxmox_virtual_environment_vm" "freeipa" {
  name        = "freeipa"
  tags        = ["tf"]
  description = <<EOT
FreeIPA, our identity management system
EOT

  node_name = "reisen"
  vm_id     = local.proxmox_freeipa_vm_id

  agent {
    # read 'Qemu guest agent' section, change to true only when ready
    enabled = false
  }

  startup {
    order      = 8
    up_delay   = 0
    down_delay = 2
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
    bridge      = "vmbr0"
    mac_address = "BC:24:11:3D:39:91"
  }
  network_device {
    mac_address = "BC:24:19:3D:39:91"
    bridge      = proxmox_virtual_environment_network_linux_bridge.internal.name
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
    ignore_changes = [started, description, operating_system[0], cdrom[0].enabled, cdrom[0].file_id]
  }
}

resource "proxmox_virtual_environment_container" "litterbox" {
  node_name   = "reisen"
  vm_id       = local.proxmox_litterbox_vm_id
  tags        = ["tf"]
  description = <<EOT
kat's box
EOT

  memory {
    dedicated = 512
    swap      = 512
  }

  disk {
    datastore_id = "local-zfs"
    size         = 64
  }

  initialization {
    hostname = "litterbox"
    ip_config {
      ipv6 {
        address = "auto"
      }
      ipv4 {
        address = "dhcp"
      }
    }
    ip_config {
      ipv6 {
        address = "${cidrhost(local.reisen_int_prefix6, local.proxmox_litterbox_vm_id - local.reisen_int_offset)}/64"
      }
      ipv4 {
        address = "${cidrhost(local.reisen_int_prefix4, local.proxmox_litterbox_vm_id - local.reisen_int_offset)}/24"
      }
    }
  }

  startup {
    order      = 4
    up_delay   = 0
    down_delay = 0
  }

  network_interface {
    name        = "eth0"
    mac_address = "BC:24:11:C4:66:AB"
  }
  network_interface {
    name        = "eth9"
    mac_address = "BC:24:19:C4:66:AB"
    bridge      = proxmox_virtual_environment_network_linux_bridge.internal.name
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
    ignore_changes = [started, unprivileged, initialization[0].dns, operating_system[0].template_file_id]
  }
}

module "litterbox_config" {
  source     = "./system/proxmox/lxc/config"
  connection = local.proxmox_reisen_connection
  container  = proxmox_virtual_environment_container.litterbox
  config     = local.proxmox_litterbox_config.lxc
}

resource "proxmox_virtual_environment_vm" "freepbx" {
  name        = "freepbx"
  tags        = ["tf"]
  description = <<EOT
FreePBX, our phone system
EOT

  node_name = "reisen"
  vm_id     = local.proxmox_freepbx_vm_id

  agent {
    # read 'Qemu guest agent' section, change to true only when ready
    enabled = false
  }

  startup {
    order      = 8
    up_delay   = 0
    down_delay = 2
  }

  cdrom {
    enabled = true
    file_id = "local:iso/SNG7-PBX16-64bit-2302-1.iso"
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
    bridge      = "vmbr0"
    mac_address = "BC:24:11:33:19:04"
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
    ignore_changes = [started, description, operating_system[0], cdrom[0].enabled, cdrom[0].file_id]
  }
}

resource "proxmox_virtual_environment_container" "keycloak" {
  node_name   = "reisen"
  vm_id       = local.proxmox_keycloak_vm_id
  tags        = ["tf"]
  description = <<EOT
keycloak
EOT

  memory {
    dedicated = 512
    swap      = 512
  }

  disk {
    datastore_id = "local-zfs"
    size         = 64
  }

  initialization {
    hostname = "keycloak"
    ip_config {
      ipv6 {
        address = "auto"
      }
      ipv4 {
        address = "10.1.1.48/24"
        gateway = "10.1.1.1"
      }
    }
    ip_config {
      ipv6 {
        address = "${cidrhost(local.reisen_int_prefix6, local.proxmox_keycloak_vm_id - local.reisen_int_offset)}/64"
      }
      ipv4 {
        address = "${cidrhost(local.reisen_int_prefix4, local.proxmox_keycloak_vm_id - local.reisen_int_offset)}/24"
      }
    }
  }

  startup {
    order      = 4
    up_delay   = 0
    down_delay = 0
  }

  network_interface {
    name        = "eth0"
    mac_address = "BC:24:11:C4:66:AC"
  }
  network_interface {
    name        = "eth9"
    mac_address = "BC:24:19:C4:66:AC"
    bridge      = proxmox_virtual_environment_network_linux_bridge.internal.name
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
    ignore_changes = [started, unprivileged, initialization[0].dns, operating_system[0].template_file_id]
  }
}

module "keycloak_config" {
  source     = "./system/proxmox/lxc/config"
  connection = local.proxmox_reisen_connection
  container  = proxmox_virtual_environment_container.keycloak
  config     = local.proxmox_keycloak_config.lxc
}
