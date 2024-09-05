variable "zone_id" {
  type      = string
  sensitive = false
}

variable "subdomains" {
  type      = list(string)
  sensitive = false
}

resource "cloudflare_record" "records" {
  for_each = toset(var.subdomains)
  name     = each.value
  proxied  = true
  ttl      = 1
  type     = "CNAME"
  content  = cloudflare_tunnel.tunnel.cname
  zone_id  = var.zone_id
}
