{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.unifi;
in {
  services.unifi = {
    enable = mkDefault true;
    unifiPackage = mkDefault pkgs.unifi8;
  };

  networking.firewall = mkIf cfg.enable {
    interfaces.lan = {
      allowedTCPPorts = [
        8443 # remote login
      ];
    };
    interfaces.local = {
      allowedTCPPorts = mkIf (!cfg.openFirewall) [
        8080 # Port for UAP to inform controller.
        8880 # Port for HTTP portal redirect, if guest portal is enabled.
        8843 # Port for HTTPS portal redirect, ditto.
        6789 # Port for UniFi mobile speed test.
      ];
      allowedUDPPorts = mkIf (!cfg.openFirewall) [
        10001 # UDP port used for device discovery.
      ];
    };
    allowedUDPPorts = mkIf (!cfg.openFirewall) [
      3478 # UDP port used for STUN.
    ];
  };

  users = mkIf cfg.enable {
    users.unifi.uid = 990;
    groups.unifi.gid = 990;
  };
  systemd.services.unifi = mkIf cfg.enable {
    gensokyo-zone.sharedMounts.unifi.path = mkDefault "/var/lib/unifi";
  };
}
