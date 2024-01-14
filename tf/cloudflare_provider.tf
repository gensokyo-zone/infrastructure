variable "cloudflare_account_email" {
  type      = string
  sensitive = false
}

variable "cloudflare_account_id" {
  type      = string
  sensitive = true
}

variable "cloudflare_api_key" {
  type      = string
  sensitive = true
}

provider "cloudflare" {
  email   = var.cloudflare_account_email
  api_key = var.cloudflare_api_key
}