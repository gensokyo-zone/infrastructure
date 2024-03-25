module "reisen_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.reisen.network
}

module "hakurei_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.hakurei.network
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
    "mqtt",
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
    "mqtt",
    "kitchen",
    "yt",
  ]
}

module "reimu_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.reimu.network
  local_subdomains = [
    "nfs",
  ]
}

module "keycloak_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.keycloak.network
}

module "utsuho_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.utsuho.network
}

module "aya_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.aya.network
  local_subdomains = [
    "nixbld",
  ]
}

module "tewi_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.tei.network
  local_subdomains = [
    "postgresql",
  ]
}

module "mediabox_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.mediabox.network
  local_subdomains = [
    "plex",
  ]
}

module "litterbox_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.litterbox.network
}

module "idp_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.freeipa.network
}

module "kubernetes_system_records" {
  source    = "./system/records"
  name      = "kubernetes"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.kuwubernetes.network
}

module "freepbx_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.freepbx.network
}

module "kitchencam_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.kitchencam.network
}

variable "u7pro_ipv6_postfix" {
  type = string
}

module "u7pro_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.u7pro.network
  local_v6  = "fd0a::${var.u7pro_ipv6_postfix}"
}

module "tewi_legacy_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.tewi.network
}
