variable "local_subdomains" {
  type    = list(string)
  default = []
}

locals {
  cname_records = concat(
    [for subdomain in var.local_subdomains : {
      name  = "${subdomain}.local",
      value = "${local.local_name}.${var.zone_zone}",
    }],
    local.has_tailscale ? [for subdomain in var.local_subdomains : {
      name  = "${subdomain}.tail",
      value = "${local.tailscale_name}.${var.zone_zone}",
    }] : [],
  )
}

resource "cloudflare_record" "cname_records" {
  for_each = { for i, cname in local.cname_records : cname.name => i }
  name     = local.cname_records[each.value].name
  proxied  = false
  ttl      = 360
  type     = "CNAME"
  value    = local.cname_records[each.value].value
  zone_id  = var.zone_id
}
