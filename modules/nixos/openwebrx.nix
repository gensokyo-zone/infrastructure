{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkOptionDefault mkForce;
  inherit (lib.trivial) mapNullable;
  cfg = config.services.openwebrx;
in {
  options.services.openwebrx = with lib.types; {
    port = mkOption {
      type = port;
      default = 8073;
      readOnly = true;
    };
    dataDir = mkOption {
      type = path;
      default = "/var/lib/openwebrx";
      readOnly = true;
    };
    user = mkOption {
      type = nullOr str;
      default = null;
    };
    group = mkOption {
      type = nullOr str;
    };
  };

  config = {
    services.openwebrx = {
      group = mkOptionDefault (mapNullable (user: config.users.users.${user}.group) cfg.user);
    };

    systemd.services.openwebrx = mkIf cfg.enable {
      serviceConfig = mkIf (cfg.user != null) {
        DynamicUser = mkForce false;
        User = cfg.user;
        Group = cfg.group;
      };
    };

    environment.systemPackages = mkIf cfg.enable [
      cfg.package
    ];
  };
}
