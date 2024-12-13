resource "cloudflare_pages_project" "wiki" {
  account_id        = var.cloudflare_account_id
  name              = "wiki"
  production_branch = "v4"

  source {
    type = "github"
    config {
      owner                         = "gensokyo-zone"
      repo_name                     = "wiki"
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

resource "cloudflare_pages_domain" "wiki" {
  account_id   = var.cloudflare_account_id
  project_name = "wiki"
  domain       = "wiki.gensokyo.zone"

  depends_on = [
    cloudflare_pages_project.wiki
  ]
}

resource "cloudflare_record" "wiki" {
  zone_id = cloudflare_zone.gensokyo-zone_zone.id
  name    = "wiki"
  proxied = false
  ttl     = 3600
  type    = "CNAME"
  value   = cloudflare_pages_project.wiki.subdomain
}
