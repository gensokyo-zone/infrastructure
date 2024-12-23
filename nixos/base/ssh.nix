{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.lists) head;
  cfg = config.services.openssh;
  publicPort = 62954;
in {
  /*
  security.pam.services.sshd.text = mkDefault (mkAfter ''
    session required pam_exec.so ${katnotify}/bin/notify
  '');
  */

  services.openssh = {
    enable = mkDefault true;
    ports = [publicPort 22];
    openFirewall = mkDefault false;
    settings = {
      PasswordAuthentication = mkDefault false;
      KbdInteractiveAuthentication = mkDefault false;
      PermitRootLogin = mkDefault "prohibit-password";
      KexAlgorithms = ["curve25519-sha256@libssh.org"];
      PubkeyAcceptedAlgorithms = mkDefault "+ssh-rsa";
      StreamLocalBindUnlink = mkDefault "yes";
      LogLevel = mkDefault "VERBOSE";
    };
  };
  networking.firewall = {
    allowedTCPPorts = [publicPort];
    interfaces.local.allowedTCPPorts = [22];
  };

  programs.mosh.enable = true;

  boot.initrd.network.ssh = mkIf cfg.enable {
    port = mkDefault (head cfg.ports);
  };
}
