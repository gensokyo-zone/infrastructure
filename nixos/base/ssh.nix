{
  config,
  lib,
  pkgs,
  ...
}: let
  publicPort = 62954;
in with lib; {
  /*
  security.pam.services.sshd.text = mkDefault (mkAfter ''
    session required pam_exec.so ${katnotify}/bin/notify
  '');
  */

  services.openssh = {
    enable = true;
    ports = lib.mkDefault [publicPort 22];
    openFirewall = false;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = lib.mkDefault "prohibit-password";
      KexAlgorithms = ["curve25519-sha256@libssh.org"];
      PubkeyAcceptedAlgorithms = "+ssh-rsa";
      StreamLocalBindUnlink = "yes";
      LogLevel = "VERBOSE";
    };
  };
  networking.firewall = {
    allowedTCPPorts = [publicPort];
    interfaces.local.allowedTCPPorts = [ 22 ];
  };

  programs.mosh.enable = true;
}
