variable "cloudflare_tunnel_secret_tewi" {
  type      = string
  sensitive = true
}

module "tewi" {
  source     = "./tunnel"
  name       = "tewi"
  secret     = var.cloudflare_tunnel_secret_tewi
  account_id = var.cloudflare_account_id
  zone_id    = cloudflare_zone.gensokyo-zone_zone.id
  subdomains = [
    "home",
    "id",
    "login",
    "z2m",
  ]
}

output "cloudflare_tunnel_id_tewi" {
  value = module.tewi.id
}

output "cloudflare_tunnel_token_tewi" {
  value = module.tewi.token
  sensitive = true
}

output "cloudflare_tunnel_cname_tewi" {
  value = module.tewi.cname
}

variable "cloudflare_tunnel_secret_mediabox" {
  type      = string
  sensitive = true
}

module "mediabox" {
  source     = "./tunnel"
  name       = "mediabox"
  secret     = var.cloudflare_tunnel_secret_mediabox
  account_id = var.cloudflare_account_id
  zone_id    = cloudflare_zone.gensokyo-zone_zone.id
  subdomains = [
    "deluge",
    "plex",
    "sonarr",
    "radarr",
    "jackett",
    "bazarr",
    "tatulli",
    "ombi",
  ]
}

output "cloudflare_tunnel_id_mediabox" {
  value = module.mediabox.id
}

output "cloudflare_tunnel_token_mediabox" {
  value = module.mediabox.token
  sensitive = true
}

output "cloudflare_tunnel_cname_mediabox" {
  value = module.mediabox.cname
}