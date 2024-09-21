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
    "login",
    "sso",
    "ldap",
    "krb5",
    "ipa",
    "ipa-cock",
    "bw",
    "unifi",
    "status",
    "prometheus",
    "mon",
    "logs",
    "pbx",
    "smb",
    "mqtt",
    "kitchen",
    "print",
    "radio",
    "lm",
    "webrx",
    "deluge",
    "task",
    "home",
    "z2m",
    "grocy",
    "bbuddy",
    "syncplay",
    "yt",
  ]
  global_subdomains = [
    "plex",
    "idp",
    "ldap",
    "krb5",
    "pbx",
    "smb",
    "mqtt",
    "kitchen",
    "print",
    "radio",
    "lm",
    "webrx",
    "syncplay",
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

module "minecraft_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.minecraft.network
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

module "kasen_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.kasen.network
  local_subdomains = [
    "rtlsdr",
  ]
}

module "sakuya_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.sakuya.network
}

module "logistics_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.logistics.network
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

module "chen_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.chen.network
}

module "koishi_system_records" {
  source    = "./system/records"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  net_data  = local.systems.koishi.network
}
