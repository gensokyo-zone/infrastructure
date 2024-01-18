{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault;
  inherit (lib.trivial) eui64;
  inherit (config) networking services;
  networkModule = { config, ... }: {
    options = with lib.types; {
      mdns = {
        enable = mkEnableOption "SLAAC" // {
          default = config.matchConfig.Type or null == "ether" && services.resolved.enable;
        };
      };
      slaac = {
        enable = mkEnableOption "SLAAC" // {
          default = config.matchConfig.Type or null == "ether" && networking.enableIPv6;
        };
        postfix = mkOption {
          type = str;
        };
      };
    };
    config = {
      slaac.postfix = mkIf (config.matchConfig.MACAddress or null != null) (
        mkOptionDefault (eui64 config.matchConfig.MACAddress)
      );
      networkConfig = mkMerge [
        (mkIf config.slaac.enable {
          IPv6AcceptRA = true;
        })
        (mkIf config.mdns.enable {
          MulticastDNS = true;
        })
      ];
      linkConfig = mkIf config.mdns.enable {
        Multicast = true;
      };
    };
  };
in {
  options.deploy.system = mkOption {
    type = lib.types.unspecified;
    readOnly = true;
  };
  options.systemd.network.networks = mkOption {
    type = with lib.types; attrsOf (submodule networkModule);
  };
  config = {
    deploy.system = config.system.build.toplevel;
  };
}
