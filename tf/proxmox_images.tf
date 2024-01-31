resource "proxmox_virtual_environment_file" "fedora39_netinstall_image" {
  content_type = "iso"
  datastore_id = "local"
  node_name    = "reisen"

  source_file {
    path = "https://download.fedoraproject.org/pub/fedora/linux/releases/39/Server/x86_64/iso/Fedora-Server-dvd-x86_64-39-1.5.iso"
  }
}