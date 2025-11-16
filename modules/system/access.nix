{
  name,
  config,
  access,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone) systems;
  inherit (gensokyo-zone.self) nixosConfigurations;
  inherit (gensokyo-zone.lib) domain mkAddress6;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.attrsets) mapAttrs attrValues;
  inherit (lib.lists) findSingle;
  inherit (lib.trivial) mapNullable;
  cfg = config.access;
  systemAccess = access;
  nixosModule = {
    config,
    systemConfig,
    access,
    ...
  }: let
    cfg = config.networking.access;
    addressForAttr =
      if config.networking.enableIPv6
      then "address6ForNetwork"
      else "address4ForNetwork";
    has'Int = systemConfig.network.networks.int.enable or false;
    has'Local = systemConfig.network.networks.local.enable or false;
    has'Tail' = systemConfig.network.networks.tail.enable or false;
    has'Tail = lib.warnIf (has'Tail' != config.services.tailscale.enable) "tailscale set incorrectly in system.access for ${config.networking.hostName}" has'Tail';
  in {
    options.networking.access = with lib.types; {
      global.enable =
        mkEnableOption "global access"
        // {
          default = systemConfig.access.global.enable;
        };
      moduleArgAttrs = mkOption {
        type = lazyAttrsOf unspecified;
        internal = true;
      };
    };
    config = {
      networking.access = {
        moduleArgAttrs = let
          mkGetAddressFor = nameAllowed: addressForAttr: hostName: network: let
            forSystem = access.systemFor hostName;
            forSystemHas = network: forSystem.access ? ${addressForAttr}.${network} || forSystem.access ? address4ForNetwork.${network};
            err = throw "no interface found between ${config.networking.hostName} -> ${hostName}@${network} OR disable promtail and prometheus-node-exporter services";
            fallback =
              if nameAllowed
              then lib.warn "getAddressFor hostname fallback for ${config.networking.hostName} -> ${hostName}@${network}" (access.getHostnameFor hostName network)
              else if forSystem.access.global.enable
              then lib.warn "getAddressFor global fallback for ${config.networking.hostName} -> ${hostName}@${network}" (mkGetAddressFor true addressForAttr hostName "global")
              else err;
            global = forSystem.access.${addressForAttr}.global or forSystem.access.address4ForNetwork.global or fallback;
            local = forSystem.access.${addressForAttr}.local or forSystem.access.address4ForNetwork.local or fallback;
            int = forSystem.access.${addressForAttr}.int or forSystem.access.address4ForNetwork.int or fallback;
            tail = forSystem.access.${addressForAttr}.tail or fallback;
          in
            {
              lan =
                if hostName == systemConfig.name
                then forSystem.access.${addressForAttr}.localhost
                else if has'Int && forSystemHas "int"
                then int
                else if has'Local && forSystemHas "local"
                then local
                else if forSystem.access.global.enable && forSystemHas "global"
                then global
                else fallback;
              ${
                if has'Local
                then "local"
                else null
              } =
                local;
              ${
                if has'Int
                then "int"
                else null
              } =
                int;
              ${
                if has'Tail
                then "tail"
                else null
              } =
                tail;
              global = global;
            }
            .${network}
            or fallback;
        in {
          inherit
            (systemAccess)
            hostnameForNetwork
            address4ForNetwork
            address6ForNetwork
            systemForService
            systemForServiceId
            ;
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
          getAddressFor = mkGetAddressFor true addressForAttr;
          getAddress4For = mkGetAddressFor false "address4ForNetwork";
          getAddress6For = mkGetAddressFor false "address6ForNetwork";
          getHostnameFor = hostName: network: let
            forSystem = access.systemFor hostName;
            err = throw "no hostname found between ${config.networking.hostName} and ${hostName}@${network}";
          in
            {
              lan =
                if hostName == systemConfig.name
                then forSystem.access.hostnameForNetwork.localhost
                else if has'Int && forSystem.access.hostnameForNetwork ? int
                then forSystem.access.hostnameForNetwork.int
                else if has'Local && forSystem.access.hostnameForNetwork ? local
                then forSystem.access.hostnameForNetwork.local
                else err;
              ${
                if has'Local
                then "local"
                else null
              } =
                forSystem.access.hostnameForNetwork.local or err;
              ${
                if has'Int
                then "int"
                else null
              } =
                forSystem.access.hostnameForNetwork.int or err;
              ${
                if has'Tail
                then "tail"
                else null
              } =
                forSystem.access.hostnameForNetwork.tail or err;
            }
            .${network}
            or err;
          proxyUrlFor = {
            system ?
              if serviceId != null
              then access.systemForServiceId serviceId
              else access.systemForService serviceName,
            serviceName ? mapNullable (serviceId: (findSingle (s: s.id == serviceId) null null (attrValues system.exports.services)).name) serviceId,
            serviceId ? null,
            service ? system.exports.services.${serviceName},
            portName ? "default",
            port ? service.ports.${portName},
            host ? access.${getAddressFor} system.name network,
            defaultPort ? null,
            network ? "lan",
            scheme ? null,
            getAddressFor ? "getAddressFor",
          }: let
            scheme' =
              if scheme == null
              then "${port.protocol}://"
              else if scheme == ""
              then ""
              else "${scheme}://";
            port' =
              if !port.enable
              then throw "${system.name}.exports.services.${service.name}.ports.${portName} isn't enabled"
              else if port.port == defaultPort
              then ""
              else ":${toString port.port}";
            url = "${scheme'}${mkAddress6 host}${port'}";
          in
            assert service.enable; url;
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
    fqdnAliases = mkOption {
      type = listOf str;
      default = [];
    };
    hostName = mkOption {
      type = str;
      default = name;
    };
    domain = mkOption {
      type = str;
      default = domain;
    };
    global.enable = mkEnableOption "globally routeable";
    online = let
      proxmoxNodeAccess = systems.${config.proxmox.node.name}.access;
    in {
      enable =
        mkEnableOption "a deployed machine"
        // {
          default = true;
        };
      available =
        mkEnableOption "always on machine"
        // {
          default = cfg.online.enable && (config.type == "NixOS" || config.proxmox.node.enable || (config.proxmox.vm.enable && proxmoxNodeAccess.online.available));
        };
    };
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
      noNetwork = {
        enable = false;
        address4 = null;
        address6 = null;
        fqdn = null;
      };
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
          localhost = mkOptionDefault "localhost";
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
          localhost = mkOptionDefault "127.0.0.1";
          lan = mkMerge [
            (mapNetwork' mkDefault "address4" int)
            (mapNetwork4 local)
          ];
        }
      ];
      address6ForNetwork = mkMerge [
        (mapAttrs (_: mapNetwork6) config.network.networks)
        {
          localhost = mkOptionDefault "::1";
          lan = mkMerge [
            (mapNetwork' mkDefault "address6" int)
            (mapNetwork6 local)
          ];
        }
      ];
    };

    _module.args.access = {
      inherit (cfg) hostnameForNetwork address4ForNetwork address6ForNetwork;
      systemFor = hostName: systems.${hostName};
      systemForOrNull = hostName: systems.${hostName} or null;
      nixosFor = hostName: nixosConfigurations.${hostName}.config or (access.systemFor hostName).built.config;
      nixosForOrNull = hostName: nixosConfigurations.${hostName}.config or (access.systemForOrNull hostName).built.config or null;
      systemForService = service: let
        hasService = system: system.exports.services.${service}.enable;
        notFound = throw "no system found serving ${service}";
        multiple = throw "multiple systems found serving ${service}";
      in (findSingle hasService notFound multiple (attrValues systems));
      systemForServiceId = serviceId: let
        hasService = system: findSingle (service: service.id == serviceId && service.enable) null multiple (attrValues system.exports.services) != null;
        notFound = throw "no system found serving ${serviceId}";
        multiple = throw "multiple systems found serving ${serviceId}";
      in (findSingle hasService notFound multiple (attrValues systems));
    };
  };
}
