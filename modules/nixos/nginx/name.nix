{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  inherit (lib.strings) optionalString;
  inherit (config.services) tailscale;
  inherit (config) networking;
  hostModule = {config, ...}: let
    cfg = config.name;
  in {
    options = with lib.types; {
      name = {
        shortServer = mkOption {
          type = nullOr str;
          default = null;
        };
        qualifier = mkOption {
          type = nullOr str;
        };
        includeLocal = mkOption {
          type = bool;
          default = false;
        };
        includeTailscale = mkOption {
          type = bool;
        };
      };
      allServerNames = mkOption {
        type = listOf str;
      };
    };

    config = {
      name = {
        qualifier = mkOptionDefault (
          if config.local.enable then "local"
          else null
        );
        includeTailscale = mkOptionDefault (
          config.local.enable && tailscale.enable && cfg.qualifier != "tail"
        );
      };
      serverName = mkIf (cfg.shortServer != null) (mkDefault (
        cfg.shortServer
        + optionalString (cfg.qualifier != null) ".${cfg.qualifier}"
        + ".${networking.domain}"
      ));
      serverAliases = mkIf (cfg.shortServer != null) (mkDefault [
        (mkIf cfg.includeLocal "${cfg.shortServer}.local.${networking.domain}")
        (mkIf cfg.includeTailscale "${cfg.shortServer}.tail.${networking.domain}")
      ]);
      allServerNames = mkOptionDefault (
        [ config.serverName ] ++ config.serverAliases
      );
    };
  };
in {
  options = with lib.types; {
    services.nginx.virtualHosts = mkOption {
      type = attrsOf (submoduleWith {
        modules = [hostModule];
        shorthandOnlyDefinesConfig = true;
      });
    };
  };
}
