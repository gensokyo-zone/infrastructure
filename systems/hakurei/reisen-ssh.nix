{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkAfter;
  username = "tf-proxmox";
  sshJump = pkgs.writeShellScript "ssh-jump-${username}" ''
    exec ssh -T \
      -oUpdateHostKeys=yes \
      -i ${config.sops.secrets.tf-proxmox-identity.path} \
      tf@reisen.local.${config.networking.domain} \
      -- "$SSH_ORIGINAL_COMMAND"
  '';
in {
  users.users.${username} = {
    hashedPasswordFile = config.sops.secrets.tf-proxmox-passwd.path;
    isNormalUser = true;
  };
  services.openssh = {
    settings = {
      KbdInteractiveAuthentication = true;
      PasswordAuthentication = true;
    };
    extraConfig = mkAfter ''
      Match User ${username}
        ForceCommand ${sshJump}
    '';
  };
  sops.secrets = {
    tf-proxmox-passwd = { };
    tf-proxmox-identity = {
      owner = username;
    };
  };
}
