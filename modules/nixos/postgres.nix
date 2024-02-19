{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkOptionDefault mkDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.lists) any;
  inherit (lib.strings) hasInfix;
  inherit (config) networking;
  cfg = config.services.postgresql;
  formatHost = host:
    if hasInfix "/" host then host
    else if hasInfix ":" host then "${host}/128"
    else if hasInfix "." host then "${host}/32"
    else throw "unsupported IP address ${host}";
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
        hosts = let
          inherit (networking.access) cidrForNetwork;
        in mkMerge [
          (mkIf config.authentication.tailscale.allow cidrForNetwork.tail.all)
          (mkIf config.authentication.local.allow (cidrForNetwork.loopback.all ++ cidrForNetwork.local.all))
        ];
        authentication = mkMerge (map (host: ''
          host ${config.authentication.database} ${config.name} ${formatHost host} ${config.authentication.method}
        '') config.authentication.hosts);
      };
      authentication.database = mkIf config.ensureDBOwnership (
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
  config.networking.firewall.interfaces.local = mkIf cfg.enable {
    allowedTCPPorts = mkIf (any (user: user.authentication.local.allow) cfg.ensureUsers) [ cfg.port ];
  };
}
