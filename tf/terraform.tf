terraform {
  required_version = ">= 1.6.0"

  required_providers {
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = ">= 4.22.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.5"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.42.1"
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
