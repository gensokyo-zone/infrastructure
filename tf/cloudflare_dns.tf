resource "cloudflare_api_token" "dyndns" {
  name = "infra-dyndns"
  policy {
    # https://developers.cloudflare.com/api/tokens/create/permissions
    permission_groups = [
      "c8fed203ed3043cba015a93ad1616f1f", # Zone Read
      "82e64a83756745bbbb1c9c2701bf816b", # DNS Read
      "4755a26eedb94da69e1066d98aa820be", # DNS Write
    ]
    resources = {
      "com.cloudflare.api.account.zone.${cloudflare_zone.gensokyo-zone_zone.id}" = "*"
    }
  }
}

output "cloudflare_dyndns_token" {
  sensitive = true
  value     = cloudflare_api_token.dyndns.value
}

variable "dyndns_record_name" {
  type = string
}

resource "cloudflare_record" "dyndns_a" {
  name    = var.dyndns_record_name
  proxied = false
  ttl     = 300
  type    = "A"
  value   = "127.0.0.1"
  zone_id = cloudflare_zone.gensokyo-zone_zone.id
}

resource "cloudflare_record" "dyndns_aaaa" {
  name    = var.dyndns_record_name
  proxied = false
  ttl     = 300
  type    = "AAAA"
  value   = "::1"
  zone_id = cloudflare_zone.gensokyo-zone_zone.id
}

output "cloudflare_dyndns_record_a" {
  value = cloudflare_record.dyndns_a.id
}

output "cloudflare_dyndns_record_aaaa" {
  value = cloudflare_record.dyndns_aaaa.id
}
