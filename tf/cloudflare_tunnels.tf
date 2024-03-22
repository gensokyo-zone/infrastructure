variable "cloudflare_tunnel_secret_hakurei" {
  type      = string
  sensitive = true
}

module "hakurei" {
  source     = "./tunnel"
  name       = "hakurei"
  secret     = var.cloudflare_tunnel_secret_hakurei
  account_id = var.cloudflare_account_id
  zone_id    = cloudflare_zone.gensokyo-zone_zone.id
  subdomains = [
    "@",
    "prox",
  ]
}

output "cloudflare_tunnel_id_hakurei" {
  value = module.hakurei.id
}

output "cloudflare_tunnel_token_hakurei" {
  value     = module.hakurei.token
  sensitive = true
}

output "cloudflare_tunnel_cname_hakurei" {
  value = module.hakurei.cname
}

variable "cloudflare_tunnel_secret_keycloak" {
  type      = string
  sensitive = true
}

module "keycloak" {
  source     = "./tunnel"
  name       = "keycloak"
  secret     = var.cloudflare_tunnel_secret_keycloak
  account_id = var.cloudflare_account_id
  zone_id    = cloudflare_zone.gensokyo-zone_zone.id
  subdomains = [
    "sso",
    "login",
  ]
}

output "cloudflare_tunnel_id_keycloak" {
  value = module.keycloak.id
}

output "cloudflare_tunnel_token_keycloak" {
  value     = module.keycloak.token
  sensitive = true
}

output "cloudflare_tunnel_cname_keycloak" {
  value = module.keycloak.cname
}

variable "cloudflare_tunnel_secret_utsuho" {
  type      = string
  sensitive = true
}

module "utsuho" {
  source     = "./tunnel"
  name       = "utsuho"
  secret     = var.cloudflare_tunnel_secret_utsuho
  account_id = var.cloudflare_account_id
  zone_id    = cloudflare_zone.gensokyo-zone_zone.id
  subdomains = [
    "unifi",
  ]
}

output "cloudflare_tunnel_id_utsuho" {
  value = module.utsuho.id
}

output "cloudflare_tunnel_token_utsuho" {
  value     = module.utsuho.token
  sensitive = true
}

output "cloudflare_tunnel_cname_utsuho" {
  value = module.utsuho.cname
}

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
    "z2m",
    "grocy",
    "bbuddy",
  ]
}

output "cloudflare_tunnel_id_tewi" {
  value = module.tewi.id
}

output "cloudflare_tunnel_token_tewi" {
  value     = module.tewi.token
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
    "sonarr",
    "radarr",
    "bazarr",
    "lidarr",
    "readarr",
    "radarr",
    "prowlarr",
    "tautulli",
    "ombi",
  ]
}

output "cloudflare_tunnel_id_mediabox" {
  value = module.mediabox.id
}

output "cloudflare_tunnel_token_mediabox" {
  value     = module.mediabox.token
  sensitive = true
}

output "cloudflare_tunnel_cname_mediabox" {
  value = module.mediabox.cname
}

variable "cloudflare_tunnel_secret_kubernetes" {
  type      = string
  sensitive = true
}

module "kubernetes" {
  source     = "./tunnel"
  name       = "kubernetes"
  secret     = var.cloudflare_tunnel_secret_kubernetes
  account_id = var.cloudflare_account_id
  zone_id    = cloudflare_zone.gensokyo-zone_zone.id
  subdomains = [
    "k8s",
  ]
}

output "cloudflare_tunnel_id_kubernetes" {
  value = module.kubernetes.id
}

output "cloudflare_tunnel_token_kubernetes" {
  value     = module.kubernetes.token
  sensitive = true
}

output "cloudflare_tunnel_cname_kubernetes" {
  value = module.kubernetes.cname
}
