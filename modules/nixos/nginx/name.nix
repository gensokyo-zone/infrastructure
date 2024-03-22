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
        localName = mkOption {
          type = nullOr str;
        };
        tailscaleName = mkOption {
          type = nullOr str;
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
        localName = mkOptionDefault (
          if cfg.includeLocal then "${cfg.shortServer}.local.${networking.domain}"
          else null
        );
        tailscaleName = mkOptionDefault (
          if cfg.includeTailscale then "${cfg.shortServer}.tail.${networking.domain}"
          else null
        );
      };
      serverName = mkIf (cfg.shortServer != null) (mkDefault (
        cfg.shortServer
        + optionalString (cfg.qualifier != null) ".${cfg.qualifier}"
        + ".${networking.domain}"
      ));
      serverAliases = mkIf (cfg.shortServer != null) (mkDefault [
        (mkIf (cfg.localName != null) cfg.localName)
        (mkIf (cfg.tailscaleName != null) cfg.tailscaleName)
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
