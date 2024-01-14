variable "account_id" {
  type      = string
  sensitive = true
}

variable "name" {
  type      = string
  sensitive = false
}

variable "secret" {
  type      = string
  sensitive = true
}

resource "cloudflare_tunnel" "tunnel" {
  account_id = var.account_id
  name       = var.name
  secret     = var.secret
  config_src = "local"
}

output "id" {
  value = cloudflare_tunnel.tunnel.id
}

output "token" {
  value = cloudflare_tunnel.tunnel.tunnel_token
  sensitive = true
}

output "cname" {
  value = cloudflare_tunnel.tunnel.cname
}