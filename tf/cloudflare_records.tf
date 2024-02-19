module "reisen_system_records" {
  source    = "./system/records"
  name      = "reisen"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  local_v4  = "10.1.1.40"
}

module "hakurei_system_records" {
  source       = "./system/records"
  name         = "hakurei"
  zone_id      = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone    = cloudflare_zone.gensokyo-zone_zone.zone
  tailscale_v4 = "100.71.65.59"
  tailscale_v6 = "fd7a:115c:a1e0::9187:413b"
  local_v4     = "10.1.1.41"
  local_v6     = "fd0a::be24:11ff:fec4:66a7"
  local_subdomains = [
    "prox",
    "id",
    "ldap",
    "freeipa",
    "smb",
    "kitchen",
    "yt",
  ]
  global_subdomains = [
    "plex",
    "idp",
    "ldap",
    "smb",
    "kitchen",
  ]
}

module "reimu_system_records" {
  source       = "./system/records"
  name         = "reimu"
  zone_id      = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone    = cloudflare_zone.gensokyo-zone_zone.zone
  tailscale_v4 = "100.113.253.48"
  tailscale_v6 = "fd7a:115c:a1e0::f1b1:fd30"
  local_v6     = "fd0a::be24:11ff:fec4:66a8"
  local_subdomains = [
    "nfs",
  ]
}

module "aya_system_records" {
  source       = "./system/records"
  name         = "aya"
  zone_id      = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone    = cloudflare_zone.gensokyo-zone_zone.zone
  tailscale_v4 = "100.109.213.94"
  tailscale_v6 = "fd7a:115c:a1e0::eaed:d55e"
  local_v4     = "10.1.1.47"
  local_v6     = "fd0a::be24:11ff:fec4:66a9"
  local_subdomains = [
    "nixbld",
  ]
}

module "tewi_system_records" {
  source       = "./system/records"
  name         = "tei"
  zone_id      = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone    = cloudflare_zone.gensokyo-zone_zone.zone
  tailscale_v4 = "100.74.104.29"
  tailscale_v6 = "fd7a:115c:a1e0::fd8a:681d"
  local_v4     = "10.1.1.39"
  local_v6     = "fd0a::be24:11ff:fecc:6657"
  local_subdomains = [
    "mqtt",
    "z2m",
    "home",
    "postgresql",
  ]
}

module "mediabox_system_records" {
  source    = "./system/records"
  name      = "mediabox"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  local_v4  = "10.1.1.44"
  local_v6  = "fd0a::be24:11ff:fe34:f4a8"
  local_subdomains = [
    "plex",
  ]
}

module "idp_system_records" {
  source    = "./system/records"
  name      = "idp"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  local_v4  = "10.1.1.46"
  local_v6  = "fd0a::be24:11ff:fe3d:3991"
}

module "kubernetes_system_records" {
  source    = "./system/records"
  name      = "kubernetes"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  local_v6  = "fd0a::be24:11ff:fe49:fedc"
}

module "kitchencam_system_records" {
  source    = "./system/records"
  name      = "kitchencam"
  zone_id   = cloudflare_zone.gensokyo-zone_zone.id
  zone_zone = cloudflare_zone.gensokyo-zone_zone.zone
  local_v6  = "fd0a::ba27:ebff:fea8:f4ff"
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
