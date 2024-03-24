module "reisen_system_records" {
  source    = "./system/records"
  name      = "reisen"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  local_v4  = "10.1.1.40"
  int_v4    = "10.9.1.2"
  int_v6    = "fd0c::2"
}

module "hakurei_system_records" {
  source       = "./system/records"
  name         = "hakurei"
  zone_id      = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone    = cloudflare_zone.gensokyo-zone_zone.zone
  net_data     = local.proxmox_reisen_systems.hakurei.network
  tailscale_v4 = "100.71.65.59"
  tailscale_v6 = "fd7a:115c:a1e0::9187:413b"
  local_subdomains = [
    "prox",
    "id",
    "login",
    "sso",
    "ldap",
    "freeipa",
    "unifi",
    "pbx",
    "smb",
    "kitchen",
    "home",
    "z2m",
    "grocy",
    "bbuddy",
    "yt",
  ]
  global_subdomains = [
    "plex",
    "idp",
    "freeipa",
    "ldap",
    "pbx",
    "smb",
    "kitchen",
    "yt",
  ]
}

module "reimu_system_records" {
  source       = "./system/records"
  name         = "reimu"
  zone_id      = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone    = cloudflare_zone.gensokyo-zone_zone.zone
  net_data     = local.proxmox_reisen_systems.reimu.network
  tailscale_v4 = "100.113.253.48"
  tailscale_v6 = "fd7a:115c:a1e0::f1b1:fd30"
  local_subdomains = [
    "nfs",
  ]
}

module "keycloak_system_records" {
  source    = "./system/records"
  name      = "keycloak"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.proxmox_reisen_systems.keycloak.network
}

module "utsuho_system_records" {
  source    = "./system/records"
  name      = "utsuho"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.proxmox_reisen_systems.utsuho.network
}

module "aya_system_records" {
  source       = "./system/records"
  name         = "aya"
  zone_id      = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone    = cloudflare_zone.gensokyo-zone_zone.zone
  net_data     = local.proxmox_reisen_systems.aya.network
  tailscale_v4 = "100.109.213.94"
  tailscale_v6 = "fd7a:115c:a1e0::eaed:d55e"
  local_subdomains = [
    "nixbld",
  ]
}

module "tewi_system_records" {
  source       = "./system/records"
  name         = "tei"
  zone_id      = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone    = cloudflare_zone.gensokyo-zone_zone.zone
  net_data     = local.proxmox_reisen_systems.tei.network
  tailscale_v4 = "100.74.104.29"
  tailscale_v6 = "fd7a:115c:a1e0::fd8a:681d"
  local_subdomains = [
    "mqtt",
    "postgresql",
  ]
}

module "mediabox_system_records" {
  source    = "./system/records"
  name      = "mediabox"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.proxmox_reisen_systems.mediabox.network
  local_subdomains = [
    "plex",
  ]
}

module "litterbox_system_records" {
  source    = "./system/records"
  name      = "litterbox"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.proxmox_reisen_systems.litterbox.network
}

module "idp_system_records" {
  source    = "./system/records"
  name      = "idp"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.proxmox_reisen_systems.freeipa.network
}

module "kubernetes_system_records" {
  source    = "./system/records"
  name      = "kubernetes"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.proxmox_reisen_systems.kuwubernetes.network
}

module "freepbx_system_records" {
  source    = "./system/records"
  name      = "freepbx"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.proxmox_reisen_systems.freepbx.network
}

module "kitchencam_system_records" {
  source    = "./system/records"
  name      = "kitchencam"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  local_v6  = "fd0a::ba27:ebff:fea8:f4ff"
}

variable "u7pro_ipv6_postfix" {
  type = string
}

module "u7pro_system_records" {
  source    = "./system/records"
  name      = "u7-pro"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  local_v4  = "10.1.1.3"
  local_v6  = "fd0a::${var.u7pro_ipv6_postfix}"
}

module "tewi_legacy_system_records" {
  source       = "./system/records"
  name         = "tewi"
  zone_id      = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone    = cloudflare_zone.gensokyo-zone_zone.zone
  tailscale_v4 = "100.88.107.41"
  tailscale_v6 = "fd7a:115c:a1e0:ab12:4843:cd96:6258:6b29"
  local_v4     = "10.1.1.38"
  local_v6     = "fd0a::eea8:6bff:fefe:3986"
}
