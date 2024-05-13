{lib, ...}: let
  inherit (lib.modules) mkForce;
in {
  config.users = {
    users.nixbld = {
      isNormalUser = true;
      isSystemUser = mkForce false;
      openssh.authorizedKeys.keys = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHV6OZ3JfVwtRhfsxYTNbh6IReZycMmfaRQrKVppX6CB extern@gensokyo-infrastructure"
      ];
    };
  };
  config.nix.settings.trusted-users = ["nixbld"];
}
