variable "local_subdomains" {
  type    = list(string)
  default = []
}

variable "global_subdomains" {
  type    = list(string)
  default = []
}

locals {
  cname_records = concat(
    [for subdomain in var.local_subdomains : {
      name  = "${subdomain}.local",
      value = "${local.local_name}.${var.zone_zone}",
    }],
    local.has_int ? [for subdomain in var.local_subdomains : {
      name  = "${subdomain}.int",
      value = "${local.int_name}.${var.zone_zone}",
    }] : [],
    local.has_tailscale ? [for subdomain in var.local_subdomains : {
      name  = "${subdomain}.tail",
      value = "${local.tailscale_name}.${var.zone_zone}",
    }] : [],
    [for subdomain in var.global_subdomains : {
      name  = subdomain,
      value = "${local.global_name}.${var.zone_zone}",
    }],
  )
}

resource "cloudflare_record" "cname_records" {
  for_each = { for i, cname in local.cname_records : cname.name => i }
  name     = local.cname_records[each.value].name
  proxied  = false
  ttl      = 600
  type     = "CNAME"
  value    = local.cname_records[each.value].value
  zone_id  = var.zone_id
}
