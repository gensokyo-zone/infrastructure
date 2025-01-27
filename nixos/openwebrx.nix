{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  cfg = config.services.openwebrx;
  user = "openwebrx";
in {
  options.services.openwebrx = with lib.types; {
    hardwareDev = mkOption {
      type = nullOr int;
    };
  };

  config.services.openwebrx = {
    enable = mkDefault true;
    package = mkDefault pkgs.openwebrxplus;
    user = mkDefault user;
    hardwareDev = mkIf config.hardware.rtl-sdr.enable (mkOptionDefault 0);
  };

  config.users = mkIf cfg.enable {
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

  config.sops.secrets = let
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

  config.networking.firewall = mkIf cfg.enable {
    interfaces.lan.allowedTCPPorts = mkIf cfg.enable [
      cfg.port
    ];
  };
}
