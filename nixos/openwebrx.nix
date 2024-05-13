{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.openwebrx;
  user = "openwebrx";
in {
  services.openwebrx = {
    enable = mkDefault true;
    package = mkDefault pkgs.openwebrxplus;
    user = mkDefault user;
  };

  users = mkIf cfg.enable {
    users.${user} = {
      uid = 912;
      isSystemUser = true;
      home = cfg.dataDir;
      group = user;
      extraGroups = mkIf config.hardware.rtl-sdr.enable [
        "plugdev"
      ];
    };
    groups.${user} = {
      gid = config.users.users.${user}.uid;
    };
  };

  sops.secrets = let
    sopsFile = mkDefault ./secrets/openwebrx.yaml;
  in
    mkIf cfg.enable {
      openwebrx-users = {
        inherit sopsFile;
        owner = cfg.user;
        group = cfg.group;
        path = "${cfg.dataDir}/users.json";
      };
    };

  networking.firewall = mkIf cfg.enable {
    interfaces.lan.allowedTCPPorts = mkIf cfg.enable [
      cfg.port
    ];
  };
}
