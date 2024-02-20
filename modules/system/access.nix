{
  name,
  config,
  lib,
  access,
  inputs,
  ...
}: let
  inherit (inputs.self.lib) systems;
  inherit (inputs.self.lib.lib) domain;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  cfg = config.access;
  systemConfig = config;
  systemAccess = access;
  nixosModule = {
    config,
    system,
    ...
  }: let
    cfg = config.networking.access;
  in {
    options.networking.access = with lib.types; {
      global.enable =
        mkEnableOption "global access"
        // {
          default = system.access.global.enable;
        };
      moduleArgAttrs = mkOption {
        type = lazyAttrsOf unspecified;
        internal = true;
      };
    };
    config = {
      networking.access = {
        moduleArgAttrs = {
          inherit (systemAccess) hostnameForNetwork;
          systemFor = hostName:
            if hostName == config.networking.hostName
            then systemConfig
            else systemAccess.systemFor hostName;
          systemForOrNull = hostName:
            if hostName == config.networking.hostName
            then systemConfig
            else systemAccess.systemForOrNull hostName;
          nixosFor = hostName:
            if hostName == config.networking.hostName
            then config
            else systemAccess.nixosFor hostName;
          nixosForOrNull = hostName:
            if hostName == config.networking.hostName
            then config
            else systemAccess.nixosForOrNull hostName;
        };
      };
      networking.tempAddresses = mkIf cfg.global.enable (
        mkDefault "disabled"
      );
      _module.args.access = config.networking.access.moduleArgAttrs;
      lib.access = config.networking.access.moduleArgAttrs;
    };
  };
in {
  options.access = with lib.types; {
    hostName = mkOption {
      type = str;
      default = name;
    };
    domain = mkOption {
      type = str;
      default = domain;
    };
    tailscale.enable = mkEnableOption "tailscale access";
    global.enable = mkEnableOption "globally routeable";
    hostnameForNetwork = mkOption {
      type = attrsOf str;
      default = {};
    };
  };
  config = {
    modules = [
      nixosModule
    ];

    access = {
      hostnameForNetwork = {
        local = mkOptionDefault "${cfg.hostName}.local.${cfg.domain}";
        tail = mkIf cfg.tailscale.enable (mkOptionDefault "${cfg.hostName}.tail.${cfg.domain}");
        global = mkIf cfg.global.enable (mkOptionDefault "${cfg.hostName}.${cfg.domain}");
      };
    };

    _module.args.access = {
      inherit (cfg) hostnameForNetwork;
      systemFor = hostName: systems.${hostName}.config;
      systemForOrNull = hostName: systems.${hostName}.config or null;
      nixosFor = hostName: (access.systemFor hostName).built.config;
      nixosForOrNull = hostName: (access.systemForOrNull hostName).built.config or null;
    };
  };
}
