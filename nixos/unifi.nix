{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault;
  cfg = config.services.unifi;
in {
  services.unifi = {
    enable = mkDefault true;
    unifiPackage = mkDefault pkgs.unifi8;
    #seems to be *much* harder to compile so not going with this for now...
    #mongodbPackage = mkDefault pkgs.mongodb-5_0;
  };

  networking.firewall.interfaces.local = mkIf cfg.enable {
    allowedTCPPorts = mkMerge [
      [
        8443 # remote login
      ]
      (mkIf (!cfg.openFirewall) [
        8080 # Port for UAP to inform controller.
        8880 # Port for HTTP portal redirect, if guest portal is enabled.
        8843 # Port for HTTPS portal redirect, ditto.
        6789 # Port for UniFi mobile speed test.
      ])
    ];
    allowedUDPPorts = mkIf (!cfg.openFirewall) [
      3478 # UDP port used for STUN.
      10001 # UDP port used for device discovery.
    ];
  };

  users = mkIf cfg.enable {
    users.unifi.uid = 990;
    groups.unifi.gid = 990;
  };
  systemd.services.unifi = mkIf cfg.enable {
    serviceConfig.BindPaths = [
      "/mnt/shared/unifi:/var/lib/unifi"
    ];
  };
}
