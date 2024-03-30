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
  inherit (lib.attrsets) mapAttrs;
  cfg = config.access;
  systemConfig = config;
  systemAccess = access;
  nixosModule = {
    config,
    system,
    access,
    ...
  }: let
    cfg = config.networking.access;
    addressForAttr = if config.networking.enableIPv6 then "address6ForNetwork" else "address4ForNetwork";
    has'Int = system.network.networks.int.enable or false;
    has'Local = system.network.networks.local.enable or false;
    has'Tail' = system.network.networks.tail.enable or false;
    has'Tail = lib.warnIf (has'Tail' != config.services.tailscale.enable) "tailscale set incorrectly in system.access for ${config.networking.hostName}" has'Tail';
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
              else if has'Local then forSystem.access.${addressForAttr}.local or err
              else err;
            ${if has'Local then "local" else null} = forSystem.access.${addressForAttr}.local or err;
            ${if has'Int then "int" else null} = forSystem.access.${addressForAttr}.int or err;
            ${if has'Tail then "tail" else null} = forSystem.access.${addressForAttr}.tail or err;
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
              if has'Int then forSystem.access.hostnameForNetwork.int or forSystem.access.hostnameForNetwork.local or err
              else if has'Local then forSystem.access.hostnameForNetwork.local or err
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
    fqdn = mkOption {
      type = str;
    };
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
      noNetwork = { enable = false; address4 = null; address6 = null; fqdn = null; };
      local = config.network.networks.local or noNetwork;
      int = config.network.networks.int or noNetwork;
      mapNetwork' = mkDefault: attr: network: mkIf (network.enable && network.${attr} != null) (mkDefault network.${attr});
      mapNetwork4 = mapNetwork' mkOptionDefault "address4";
      mapNetwork6 = mapNetwork' mkOptionDefault "address6";
      mapNetworkFqdn = mapNetwork' mkOptionDefault "fqdn";
    in {
      fqdn = mkOptionDefault "${cfg.hostName}.${cfg.domain}";
      hostnameForNetwork = mkMerge [
        (mapAttrs (_: mapNetworkFqdn) config.network.networks)
        {
          lan = mkMerge [
            (mapNetwork' mkDefault "fqdn" int)
            (mapNetworkFqdn local)
          ];
          global = mkIf cfg.global.enable (mkOptionDefault cfg.fqdn);
        }
      ];
      address4ForNetwork = mkMerge [
        (mapAttrs (_: mapNetwork4) config.network.networks)
        {
          lan = mkMerge [
            (mapNetwork' mkDefault "address4" int)
            (mapNetwork4 local)
          ];
        }
      ];
      address6ForNetwork = mkMerge [
        (mapAttrs (_: mapNetwork6) config.network.networks)
        {
          lan = mkMerge [
            (mapNetwork' mkDefault "address6" int)
            (mapNetwork6 local)
          ];
        }
      ];
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
