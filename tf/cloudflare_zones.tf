variable "bypass_cloudflare" {
  type    = bool
  default = false
}

variable "cloudflare_plan" {
  type    = string
  default = "free"
}

resource "cloudflare_zone" "gensokyo-zone_zone" {
  account_id = var.cloudflare_account_id
  zone       = "gensokyo.zone"
  paused     = var.bypass_cloudflare
  plan       = var.cloudflare_plan
  type       = "full"
}

output "gensokyo-zone_zone_id" {
  value = cloudflare_zone.gensokyo-zone_zone.id
}