locals {
  tailscale_tag_infra     = "tag:infrastructure"
  tailscale_tag_genso     = "tag:gensokyo"
  tailscale_tag_reisen    = "tag:reisen"
  tailscale_tag_minecraft = "tag:minecraft"

  tailscale_tag_arc        = "tag:arc"
  tailscale_tag_arc_deploy = "tag:arc-deploy"
  tailscale_tag_kat        = "tag:kat"
  tailscale_tag_kat_deploy = "tag:kat-deploy"

  tailscale_user_arc = "arc@${var.tailscale_tailnet}"
  tailscale_user_kat = "kat@${var.tailscale_tailnet}"

  tailscale_group_member = "autogroup:member"
  tailscale_group_admin  = "autogroup:admin"

  tailscale_tags_genso  = [local.tailscale_tag_infra, local.tailscale_tag_genso]
  tailscale_tags_reisen = concat(local.tailscale_tags_genso, [local.tailscale_tag_reisen])
  tailscale_tags_arc    = [local.tailscale_user_arc, local.tailscale_tag_arc]
  tailscale_tags_kat    = [local.tailscale_user_kat, local.tailscale_tag_kat]
  tailscale_tags_peeps  = concat(local.tailscale_tags_arc, local.tailscale_tags_kat)
}

resource "tailscale_acl" "tailnet" {
  acl = jsonencode({
    tagOwners = {
      "${local.tailscale_tag_infra}" : [local.tailscale_group_admin],
      "${local.tailscale_tag_reisen}" : [local.tailscale_group_admin, local.tailscale_tag_infra],
      "${local.tailscale_tag_genso}" : [local.tailscale_group_admin, local.tailscale_tag_arc_deploy, local.tailscale_tag_kat_deploy],
      "${local.tailscale_tag_minecraft}" : [local.tailscale_group_admin, local.tailscale_tag_infra],
      "${local.tailscale_tag_arc}" : [local.tailscale_user_arc, local.tailscale_tag_arc_deploy],
      "${local.tailscale_tag_arc_deploy}" : [local.tailscale_user_arc],
      "${local.tailscale_tag_kat}" : [local.tailscale_user_kat, local.tailscale_tag_kat_deploy],
      "${local.tailscale_tag_kat_deploy}" : [local.tailscale_user_kat],
    }
    acls = [
      {
        action = "accept"
        src    = [local.tailscale_group_admin]
        dst    = ["*:*"]
      },
      {
        action = "accept"
        src    = [local.tailscale_tag_reisen]
        dst    = ["${local.tailscale_tag_reisen}:*"]
      },
      {
        action = "accept"
        src    = concat([local.tailscale_tag_genso], local.tailscale_tags_peeps)
        dst = [
          "${local.tailscale_tag_genso}:*",
        ]
      },
      {
        action = "accept"
        src    = ["*"]
        dst = [
          "autogroup:self:*",
          "${local.tailscale_tag_minecraft}:19132,19133,25565",
        ]
      },
      {
        action = "accept"
        src    = [local.tailscale_group_member]
        dst    = ["autogroup:internet:*"]
      },
    ]
    # Define users and devices that can use Tailscale SSH.
    ssh = [
      # Allow all users to SSH into their own devices in check mode.
      {
        action = "check",
        src    = [local.tailscale_group_member],
        dst    = ["autogroup:self"],
        users  = ["autogroup:nonroot", "root"],
      },
    ],
  })
}

resource "tailscale_tailnet_key" "reisen" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  description   = "Reisen VM"
  tags          = local.tailscale_tags_reisen
  depends_on    = [tailscale_acl.tailnet]
}

resource "tailscale_tailnet_key" "gensokyo" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  description   = "Reisen VM"
  tags          = local.tailscale_tags_genso
  depends_on    = [tailscale_acl.tailnet]
}

output "tailscale_key_reisen" {
  value     = tailscale_tailnet_key.reisen.key
  sensitive = true
}

output "tailscale_key_gensokyo" {
  value     = tailscale_tailnet_key.gensokyo.key
  sensitive = true
}
