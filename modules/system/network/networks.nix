{config, lib, inputs, ...}: let
  inherit (inputs.self.lib.lib) eui64;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkOptionDefault;
  inherit (lib.trivial) mapNullable;
  networkModule = { config, name, system, ... }: let
    slaacPrefix = {
      local = "fd0a:";
      #int = "fd0c:";
    };
  in {
    options = with lib.types; {
      enable = mkEnableOption "network" // {
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
        enable = mkOptionDefault (slaacPrefix ? ${config.name});
        prefix = mkIf (slaacPrefix ? ${config.name}) (mkOptionDefault slaacPrefix.${config.name});
        postfix = mkIf (config.macAddress != null) (mkOptionDefault (eui64 config.macAddress));
      };
      domain = mkOptionDefault "${config.name}.${system.access.domain}";
      fqdn = mkOptionDefault (mapNullable (domain: "${system.access.hostName}.${domain}") config.domain);
      address6 = mkIf config.slaac.enable (mkOptionDefault "${config.slaac.prefix}:${config.slaac.postfix}");
    };
  };
in {
  options.network = with lib.types; {
    networks = mkOption {
      type = attrsOf (submoduleWith {
        modules = [ networkModule ];
        specialArgs = {
          system = config;
        };
      });
      default = { };
    };
  };
}
