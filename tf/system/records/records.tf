variable "zone_id" {
  type = string
}

variable "zone_zone" {
  type = string
}

variable "name" {
  type    = string
  default = null
}

variable "net_data" {
  type = any
  default = {
    hostName = null
    networks = {
      local = null
      int   = null
      tail  = null
    }
  }
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

variable "int_name" {
  type    = string
  default = null
}

variable "int_v4" {
  type    = string
  default = null
}

variable "int_v6" {
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
  name           = coalesce(var.name, var.net_data.hostName)
  local_name     = coalesce(var.local_name, "${local.name}.local")
  local_net      = coalesce(var.net_data.networks.local, local.empty_net)
  local_v4       = coalesce(var.local_v4, local.local_net.address4, local.empty_address)
  local_v6       = coalesce(var.local_v6, local.local_net.address6, local.empty_address)
  int_name       = coalesce(var.int_name, "${local.name}.int")
  int_net        = coalesce(var.net_data.networks.int, local.empty_net)
  int_v4         = coalesce(var.int_v4, local.int_net.address4, local.empty_address)
  int_v6         = coalesce(var.int_v6, local.int_net.address6, local.empty_address)
  tailscale_name = coalesce(var.tailscale_name, "${local.name}.tail")
  tailscale_net  = coalesce(var.net_data.networks.tail, local.empty_net)
  tailscale_v4   = coalesce(var.tailscale_v4, local.tailscale_net.address4, local.empty_address)
  tailscale_v6   = coalesce(var.tailscale_v6, local.tailscale_net.address6, local.empty_address)
  global_name    = coalesce(var.global_name, local.name)

  has_tailscale = local.tailscale_v4 != local.empty_address || local.tailscale_v6 != local.empty_address
  has_int       = local.int_v4 != local.empty_address || local.int_v6 != local.empty_address
  empty_address = "EMPTY"
  empty_net = {
    address4 = null
    address6 = null
  }

  a_records = [
    {
      name  = local.local_name,
      value = local.local_v4,
    },
    {
      name  = local.global_name,
      value = var.global_v4,
    },
    {
      name  = local.int_name,
      value = local.int_v4,
    },
    {
      name  = local.tailscale_name,
      value = local.tailscale_v4,
    }
  ]

  aaaa_records = [
    {
      name  = local.local_name,
      value = local.local_v6,
    },
    {
      name  = local.global_name,
      value = var.global_v6,
    },
    {
      name  = local.int_name,
      value = local.int_v6,
    },
    {
      name  = local.tailscale_name,
      value = local.tailscale_v6,
    }
  ]
}

resource "cloudflare_record" "a_records" {
  for_each = { for i, a in local.a_records : a.name => i if a.value != null && a.value != local.empty_address }
  name     = local.a_records[each.value].name
  proxied  = false
  ttl      = 3600
  type     = "A"
  content  = local.a_records[each.value].value
  zone_id  = var.zone_id
}

resource "cloudflare_record" "aaaa_records" {
  for_each = { for i, aaaa in local.aaaa_records : aaaa.name => i if aaaa.value != null && aaaa.value != local.empty_address }
  name     = local.aaaa_records[each.value].name
  proxied  = false
  ttl      = 3600
  type     = "AAAA"
  content  = local.aaaa_records[each.value].value
  zone_id  = var.zone_id
}
