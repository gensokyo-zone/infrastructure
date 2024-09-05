resource "tailscale_acl" "tailnet" {
  acl = jsonencode({
    tagOwners = {
      "tag:reisen" : ["autogroup:admin"],
      "tag:gensokyo" : ["autogroup:admin"],
    }
    acls = [
      {
        # Allow all connections
        action = "accept"
        src    = ["*"]
        dst    = ["*:*"]
      },
    ]
    # Define users and devices that can use Tailscale SSH.
    ssh = [
      # Allow all users to SSH into their own devices in check mode.
      {
        action = "check",
        src    = ["autogroup:member"],
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
  tags          = ["tag:gensokyo", "tag:reisen"]
  depends_on    = [tailscale_acl.tailnet]
}

output "tailscale_key_reisen" {
  value     = tailscale_tailnet_key.reisen.key
  sensitive = true
}
