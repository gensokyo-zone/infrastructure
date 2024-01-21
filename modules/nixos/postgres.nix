{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkOptionDefault mkDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.lists) any;
  cfg = config.services.postgresql;
  ensureUserModule = { config, ... }: {
    options = with lib.types; {
      authentication = {
        enable = mkEnableOption "TCP connections" // {
          default = config.authentication.hosts != [ ];
        };
        hosts = mkOption {
          type = listOf str;
          default = [ ];
        };
        method = mkOption {
          type = str;
          default = "md5";
        };
        database = mkOption {
          type = str;
        };
        tailscale = {
          allow = mkEnableOption "tailscale TCP connections";
        };
        local = {
          allow = mkEnableOption "local TCP connections";
        };
        authentication = mkOption {
          type = lines;
          default = "";
        };
      };
    };
    config = {
      authentication = {
        hosts = mkMerge [
          (mkIf config.authentication.tailscale.allow [
            "fd7a:115c:a1e0::/96"
            "fd7a:115c:a1e0:ab12::/64"
            "100.64.0.0/10"
          ])
          (mkIf config.authentication.local.allow [
            "10.1.1.0/24"
            "fd0a::/64"
          ])
        ];
        authentication = mkMerge (map (host: ''
          host ${config.authentication.database} ${config.name} ${host} ${config.authentication.method}
        '') config.authentication.hosts);
      };
      authentication.database = mkIf (config.ensureDBOwnership) (
        mkOptionDefault config.name
      );
    };
  };
in {
  options.services.postgresql = with lib.types; {
    ensureUsers = mkOption {
      type = listOf (submodule ensureUserModule);
    };
  };
  config.services.postgresql = {
    enableTCPIP = mkIf (any (user: user.authentication.enable) cfg.ensureUsers) (
      mkDefault true
    );
    authentication = mkMerge (map (user:
      mkIf user.authentication.enable user.authentication.authentication
    ) cfg.ensureUsers);
  };
}
