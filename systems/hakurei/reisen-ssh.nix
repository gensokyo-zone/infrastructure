{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkAfter mkForce;
  sshPort = 41022;
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
    uid = 4000;
    hashedPasswordFile = config.sops.secrets.tf-proxmox-passwd.path;
    isNormalUser = true;
    autoSubUidGidRange = false;
    group = username;
    openssh.matchBlock.settings = {
      # PasswordAuthentication works too
      KbdInteractiveAuthentication = true;
      ForceCommand = sshJump;
    };
  };
  users.groups.${username} = {
    gid = config.users.users.${username}.uid;
  };

  services.openssh = {
    ports = mkAfter [ sshPort ];
  };
  # required for kbd or password authentication
  security.pam.services.sshd.unixAuth = mkForce true;

  networking.firewall.allowedTCPPorts = [ sshPort ];

  sops.secrets = {
    tf-proxmox-passwd = { };
    tf-proxmox-identity = {
      owner = username;
    };
  };
}
