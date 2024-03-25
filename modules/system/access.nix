{
  name,
  config,
  lib,
  access,
  inputs,
  ...
}: let
  inherit (inputs.self) nixosConfigurations;
  inherit (inputs.self.lib) systems;
  inherit (inputs.self.lib.lib) domain;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.strings) removeSuffix;
  cfg = config.access;
  systemConfig = config;
  systemAccess = access;
  hasInt = config.proxmox.enabled && config.proxmox.network.internal.interface != null;
  hasLocal = config.proxmox.enabled && config.proxmox.network.local.interface != null;
  hasTail = cfg.tailscale.enable;
  nixosModule = {
    config,
    system,
    access,
    ...
  }: let
    cfg = config.networking.access;
    addressForAttr = if config.networking.enableIPv6 then "address6ForNetwork" else "address4ForNetwork";
    has'Int = system.proxmox.enabled && system.proxmox.network.internal.interface != null;
    has'Local = system.proxmox.enabled && system.proxmox.network.local.interface != null;
    has'Tail' = config.services.tailscale.enable;
    has'Tail = lib.warnIf (hasTail != has'Tail') "tailscale set incorrectly in system.access for ${config.networking.hostName}" has'Tail';
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
        moduleArgAttrs = let
          mkGetAddressFor = addressForAttr: hostName: network: let
            forSystem = access.systemFor hostName;
            err = throw "no lan interface found between ${config.networking.hostName} and ${hostName}";
          in {
            lan =
              if has'Int then forSystem.access.${addressForAttr}.int or forSystem.access.${addressForAttr}.local or err
              else if hasLocal then forSystem.access.${addressForAttr}.local or err
              else err;
            ${if has'Local then "local" else null} = forSystem.access.${addressForAttr}.local or err;
            ${if has'Int then "int" else null} = forSystem.access.${addressForAttr}.int or err;
            # TODO: tail
          }.${network} or err;
        in {
          inherit (systemAccess) hostnameForNetwork address4ForNetwork address6ForNetwork;
          addressForNetwork = systemAccess.${addressForAttr};
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
          getAddressFor = mkGetAddressFor addressForAttr;
          getAddress4For = mkGetAddressFor "address4ForNetwork";
          getAddress6For = mkGetAddressFor "address6ForNetwork";
          getHostnameFor = hostName: network: let
            forSystem = access.systemFor hostName;
            err = throw "no ${network} interface found between ${config.networking.hostName} and ${hostName}";
          in {
            lan =
              if hasInt then forSystem.access.hostnameForNetwork.int or forSystem.access.hostnameForNetwork.local or err
              else if hasLocal then forSystem.access.hostnameForNetwork.local or err
              else err;
            ${if has'Local then "local" else null} = forSystem.access.hostnameForNetwork.local or err;
            ${if has'Int then "int" else null} = forSystem.access.hostnameForNetwork.int or err;
            ${if has'Tail then "tail" else null} = forSystem.access.hostnameForNetwork.tail or err;
          }.${network} or err;
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
    address4ForNetwork = mkOption {
      type = attrsOf str;
      default = {};
    };
    address6ForNetwork = mkOption {
      type = attrsOf str;
      default = {};
    };
  };
  config = {
    modules = [
      nixosModule
    ];

    access = let
      local'interface = config.proxmox.network.local.interface;
      int'interface = config.proxmox.network.internal.interface;
      hasInt4 = hasInt && int'interface.address4 != null;
      hasInt6 = hasInt && int'interface.address6 != null;
      hasLocal4 = hasLocal && local'interface.local.address4 or null != null;
      hasLocal6 = hasLocal && local'interface.local.address6 or null != null;
    in {
      hostnameForNetwork = let
        int = "${cfg.hostName}.int.${cfg.domain}";
        local = "${cfg.hostName}.local.${cfg.domain}";
        tail = "${cfg.hostName}.tail.${cfg.domain}";
        global = "${cfg.hostName}.${cfg.domain}";
      in {
        lan = mkMerge [
          (mkIf hasInt (mkDefault int))
          (mkOptionDefault local)
        ];
        int = mkIf hasInt (mkOptionDefault int);
        local = mkOptionDefault local;
        tail = mkIf hasTail (mkOptionDefault tail);
        global = mkIf cfg.global.enable (mkOptionDefault global);
      };
      address4ForNetwork = let
        int = removeSuffix "/24" int'interface.address4;
        local = removeSuffix "/24" local'interface.local.address4;
      in {
        lan = mkMerge [
          (mkIf hasInt4 (mkDefault int))
          (mkIf hasLocal4 (mkOptionDefault local))
        ];
        int = mkIf hasInt4 (mkOptionDefault int);
        local = mkIf hasLocal4 (mkOptionDefault local);
        # TODO: tail
      };
      address6ForNetwork = let
        int = removeSuffix "/64" int'interface.address6;
        local = removeSuffix "/64" local'interface.local.address6;
      in {
        lan = mkMerge [
          (mkIf hasInt6 (mkDefault int))
          (mkIf hasLocal6 (mkOptionDefault local))
        ];
        int = mkIf hasInt6 (mkOptionDefault int);
        local = mkIf hasLocal6 (mkOptionDefault local);
        # TODO: tail
      };
    };

    _module.args.access = {
      inherit (cfg) hostnameForNetwork address4ForNetwork address6ForNetwork;
      systemFor = hostName: systems.${hostName}.config;
      systemForOrNull = hostName: systems.${hostName}.config or null;
      nixosFor = hostName: nixosConfigurations.${hostName}.config or (access.systemFor hostName).built.config;
      nixosForOrNull = hostName: nixosConfigurations.${hostName}.config or (access.systemForOrNull hostName).built.config or null;
    };
  };
}
