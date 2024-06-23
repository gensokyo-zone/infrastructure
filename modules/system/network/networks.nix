{
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) eui64;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkOptionDefault;
  inherit (lib.trivial) mapNullable;
  networkModule = {
    config,
    name,
    systemConfig,
    ...
  }: let
    knownNetworks = {
      local.slaac = {
        enable = true;
        prefix = "fd0a:";
      };
      int.slaac.prefix = "fd0c:";
    };
  in {
    options = with lib.types; {
      enable =
        mkEnableOption "network"
        // {
          default = true;
        };
      slaac = {
        enable = mkOption {
          type = bool;
        };
        prefix = mkOption {
          type = str;
        };
        postfix = mkOption {
          type = str;
        };
      };
      name = mkOption {
        type = str;
        default = name;
      };
      domain = mkOption {
        type = nullOr str;
      };
      fqdn = mkOption {
        type = nullOr str;
      };
      macAddress = mkOption {
        type = nullOr str;
        default = null;
      };
      address4 = mkOption {
        type = nullOr str;
      };
      address6 = mkOption {
        type = nullOr str;
      };
    };
    config = {
      slaac = {
        enable = mkOptionDefault (knownNetworks.${config.name}.slaac.enable or false);
        prefix = mkIf (knownNetworks.${config.name}.slaac.prefix or null != null) (
          mkOptionDefault knownNetworks.${config.name}.slaac.prefix
        );
        postfix = mkIf (config.macAddress != null) (mkOptionDefault (eui64 config.macAddress));
      };
      domain = mkOptionDefault "${config.name}.${systemConfig.access.domain}";
      fqdn = mkOptionDefault (mapNullable (domain: "${systemConfig.access.hostName}.${domain}") config.domain);
      address6 = mkIf config.slaac.enable (mkOptionDefault "${config.slaac.prefix}:${config.slaac.postfix}");
    };
  };
in {
  options.network = with lib.types; {
    networks = mkOption {
      type = attrsOf (submoduleWith {
        modules = [networkModule];
        specialArgs = {
          systemConfig = config;
        };
      });
      default = {};
    };
  };
}
