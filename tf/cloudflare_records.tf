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
