data "proxmox_virtual_environment_vm" "kubernetes" {
  node_name = "reisen"
  vm_id     = 201
}
