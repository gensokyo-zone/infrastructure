variable "zone_id" {
  type = string
}

variable "zone_zone" {
  type = string
}

variable "name" {
  type = string
}

variable "tailscale_name" {
  type    = string
  default = null
}

variable "tailscale_v4" {
  type    = string
  default = null
}

variable "tailscale_v6" {
  type    = string
  default = null
}

variable "local_name" {
  type    = string
  default = null
}

variable "local_v4" {
  type    = string
  default = null
}

variable "local_v6" {
  type    = string
  default = null
}

variable "global_name" {
  type    = string
  default = null
}

variable "global_v4" {
  type    = string
  default = null
}

variable "global_v6" {
  type    = string
  default = null
}

locals {
  local_name     = coalesce(var.local_name, "${var.name}.local")
  tailscale_name = coalesce(var.tailscale_name, "${var.name}.tail")
  global_name    = coalesce(var.global_name, var.name)

  has_tailscale = var.tailscale_v4 != null || var.tailscale_v6 != null

  a_records = [
    {
      name  = local.local_name,
      value = var.local_v4,
    },
    {
      name  = local.global_name,
      value = var.global_v4,
    },
    {
      name  = local.tailscale_name,
      value = var.tailscale_v4,
    }
  ]

  aaaa_records = [
    {
      name  = local.local_name,
      value = var.local_v6,
    },
    {
      name  = local.global_name,
      value = var.global_v6,
    },
    {
      name  = local.tailscale_name,
      value = var.tailscale_v6,
    }
  ]
}

resource "cloudflare_record" "a_records" {
  for_each = { for i, a in local.a_records : a.name => i if a.value != null }
  name     = local.a_records[each.value].name
  proxied  = false
  ttl      = 3600
  type     = "A"
  value    = local.a_records[each.value].value
  zone_id  = var.zone_id
}

resource "cloudflare_record" "aaaa_records" {
  for_each = { for i, aaaa in local.aaaa_records : aaaa.name => i if aaaa.value != null }
  name     = local.aaaa_records[each.value].name
  proxied  = false
  ttl      = 3600
  type     = "AAAA"
  value    = local.aaaa_records[each.value].value
  zone_id  = var.zone_id
}
