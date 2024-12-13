resource "cloudflare_pages_project" "gw2gwiki" {
  account_id        = var.cloudflare_account_id
  name              = "gw2wiki"
  production_branch = "v4"

  source {
    type = "github"
    config {
      owner                         = "gensokyo-zone"
      repo_name                     = "gw2wiki"
      production_branch             = "v4"
      deployments_enabled           = true
      pr_comments_enabled           = false
      production_deployment_enabled = true
    }
  }
  build_config {
    build_command   = "npx quartz build"
    destination_dir = "public"
    root_dir        = "/"
  }
  lifecycle {
    ignore_changes = [
      deployment_configs,
      source
    ]
  }
}

resource "cloudflare_pages_domain" "gw2wiki" {
  account_id   = var.cloudflare_account_id
  project_name = "gw2wiki"
  domain       = "gw2.gensokyo.zone"

  depends_on = [
    cloudflare_pages_project.gw2wiki
  ]
}

resource "cloudflare_record" "gw2wiki" {
  zone_id = cloudflare_zone.gensokyo-zone_zone.id
  name    = "gw2"
  proxied = false
  ttl     = 3600
  type    = "CNAME"
  value   = cloudflare_pages_project.gw2wiki.subdomain
}
