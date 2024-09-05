variable "tailscale_oauth_client_id" {
  type      = string
  sensitive = false
}

variable "tailscale_oauth_client_secret" {
  type      = string
  sensitive = true
}

variable "tailscale_tailnet" {
  type      = string
  sensitive = false
  default   = "gensokyo.zone"
}

provider "tailscale" {
  oauth_client_id     = var.tailscale_oauth_client_id
  oauth_client_secret = var.tailscale_oauth_client_secret
  tailnet             = var.tailscale_tailnet
}
