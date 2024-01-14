terraform {
  required_version = ">= 1.6.0"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 4.22.0"
    }
  }

  cloud {
    organization = "gensokyo-zone"
    hostname     = "app.terraform.io"

    workspaces {
      name = "infrastructure"
    }
  }
}