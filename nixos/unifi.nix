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
    mongodbPackage = let
      mongodb-5_0_26 = pkgs.mongodb-5_0.overrideAttrs (old: rec {
        version = "5.0.26";
        name = "${old.pname}-${version}";
        src = pkgs.fetchFromGitHub {
          owner = "mongodb";
          repo = "mongo";
          rev = "r${version}";
          sha256 = "sha256-lVRTrEnwuyKETFL1C8bVqBfrDaYrbQIdmHN42CF8ZIw=";
        };
        sconsFlags = old.sconsFlags ++ [
          "MONGO_VERSION=${version}"
        ];
      });
      isUpdated = lib.versionAtLeast pkgs.mongodb-5_0.version mongodb-5_0_26.version;
      message = "mongodb 5.0 updated in upstream nixpkgs, override no longer needed";
    in if !isUpdated then mongodb-5_0_26 else lib.warn message pkgs.mongodb-5_0;
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
