variable "acme_account_email" {
  type = string
}

provider "acme" {
  server_url = "https://acme-v02.api.letsencrypt.org/directory"
}

resource "tls_private_key" "acme_account_key" {
  algorithm   = "ECDSA"
  ecdsa_curve = "P384"
}

resource "acme_registration" "account" {
  account_key_pem = tls_private_key.acme_account_key.private_key_pem
  email_address   = var.acme_account_email
}

output "acme_account_key" {
  sensitive = true
  value     = tls_private_key.acme_account_key.private_key_pem
}

output "acme_account_url" {
  sensitive = true
  value     = tls_private_key.acme_account_key.id
}
