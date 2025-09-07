terraform {
  required_version = ">= 1.6.0"

  required_providers {
    acme = {
      source  = "vancluever/acme"
      version = "~> 2.0"
    }
    cloudflare = {
      source  = "cloudflare/cloudflare"
      # XXX: 5.0 requires manual migration
      version = "~> 4.22"
    }
    proxmox = {
      source  = "bpg/proxmox"
      version = ">= 0.42.1"
    }
    random = {
      source  = "hashicorp/random"
      version = ">= 3.6.0"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = ">= 0.16.2"
    }
    tls = {
      source  = "hashicorp/tls"
      version = ">= 4.0.5"
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
