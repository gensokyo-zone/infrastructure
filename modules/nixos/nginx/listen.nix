{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault mkForce mkOverride;
  inherit (lib.attrsets) mapAttrsToList filterAttrs removeAttrs;
  inherit (lib.lists) concatMap;
  mkAlmostOptionDefault = mkOverride 1250;
  inherit (config.services) nginx;
  extraListenAttrs = [ "enable" ];
  listenModule = { config, virtualHost, ... }: {
    options = with lib.types; {
      enable = mkEnableOption "this port" // {
        default = true;
      };
      ssl = mkOption {
        type = bool;
        default = false;
      };
      port = mkOption {
        type = nullOr port;
      };
    };
    config = {
      enable = mkIf (config.ssl && !virtualHost.ssl.enable) (mkForce false);
      _module.freeformType = with lib.types; attrsOf (oneOf [
        str (listOf str) (nullOr port) bool
      ]);
      port = mkOptionDefault (
        if config.ssl then nginx.defaultSSLListenPort else nginx.defaultHTTPListenPort
      );
    };
  };
  hostModule = { config, ... }: let
    cfg = config.listenPorts;
    enabledPorts = filterAttrs (_: port: port.enable) cfg;
  in {
    options = with lib.types; {
      listenPorts = mkOption {
        type = attrsOf (submoduleWith {
          modules = [ listenModule ];
          specialArgs = {
            virtualHost = config;
          };
        });
        default = { };
      };
    };

    config = {
      listen = let
        addresses = if config.listenAddresses != [ ] then config.listenAddresses else nginx.defaultListenAddresses;
      in mkIf (cfg != { }) (mkAlmostOptionDefault (
        concatMap (addr: mapAttrsToList (_: listen: {
          addr = mkDefault addr;
        } // removeAttrs listen extraListenAttrs) enabledPorts) addresses
      ));
    };
  };
in {
  options = with lib.types; {
    services.nginx.virtualHosts = mkOption {
      type = attrsOf (submoduleWith {
        modules = [ hostModule ];
        shorthandOnlyDefinesConfig = true;
      });
    };
  };
}
