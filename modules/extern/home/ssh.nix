let
  sshHostModule = {
    lib,
    gensokyo-zone,
    osConfig,
    homeConfig,
    config,
    name,
    ...
  }: let
    inherit (gensokyo-zone.lib) unmerged coalesce mkAlmostOptionDefault mapListToAttrs;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkMerge mkOptionDefault mkDefault;
    inherit (lib.lists) length head elem optional filter unique intersectLists;
    inherit (lib.attrsets) filterAttrs mapAttrsToList nameValuePair;
    inherit (lib.strings) optionalString;
    inherit (osConfig.gensokyo-zone) access;
    cfg = gensokyo-zone.ssh.cfg;
    system = gensokyo-zone.systems.${config.systemName}.config;
  in {
    options = with lib.types; {
      enable = mkEnableOption "ssh client configuration" // {
        default = true;
      };
      name = mkOption {
        type = str;
        default = name;
      };
      systemName = mkOption {
        type = str;
      };
      user = mkOption {
        type = nullOr str;
        default = cfg.user;
      };
      networks = mkOption {
        type = listOf (nullOr str);
      };
      hostName = mkOption {
        type = nullOr str;
      };
      extraOptions = mkOption {
        type = unmerged.types.attrs;
      };
      set = {
        matchBlocksSettings = mkOption {
          type = unmerged.types.attrs;
          default = {};
        };
      };
    };
    config = {
      hostName = mkOptionDefault system.access.hostName;
      extraOptions = mkOptionDefault (unmerged.mergeAttrs cfg.extraOptions);
      user = mkIf (config.systemName == "u7pro") (mkAlmostOptionDefault "kittywitch");
      networks = let
        enabledNetworks = filterAttrs (_: net: net.enable) system.network.networks;
        networkNames = mapAttrsToList (_: net: net.name) enabledNetworks;
        networks' = filter (name: name == null || elem name networkNames) cfg.networks;
        fallbackNetwork =
          if system.network.networks.local.enable or false && access.local.enable then "local"
          else if system.access.global.enable then null
          else if system.network.networks.int.enable or false then "int"
          else if system.network.networks.local.enable or false then "local"
          else null;
        networks = map (name: coalesce [ name fallbackNetwork ]) networks';
      in mkOptionDefault (unique networks);
      set = {
        matchBlocksSettings = let
          canonNetworkName' = intersectLists config.networks [ null "int" "local" ];
          canonNetworkName = if canonNetworkName' != [ ] then head canonNetworkName' else null;
        in mapListToAttrs (network: let
          name = config.name + optionalString (network != canonNetworkName) "-${network}";
          inherit (system.exports.services) sshd;
          port = head (
            optional (network == null && sshd.ports.global.enable or false) sshd.ports.global.port
            ++ optional (sshd.ports.public.enable or false) sshd.ports.public.port
            ++ [ sshd.ports.standard.port ]
          );
          needsProxy = network == "int" || (network == "local" && !access.local.enable);
        in nameValuePair name {
          hostname = mkDefault (
            if network == null then system.access.fqdn
            else system.network.networks.${network}.fqdn
          );
          user = mkIf (config.user != null) (mkDefault config.user);
          port = mkIf (port != 22) (mkDefault port);
          proxyJump = mkIf needsProxy (assert config.name != cfg.proxyJump;
            mkAlmostOptionDefault cfg.proxyJump
          );
          identitiesOnly = mkIf (config.systemName == "u7pro") (mkAlmostOptionDefault true);
          extraOptions = mkMerge [
            (unmerged.mergeAttrs config.extraOptions)
            {
              HostKeyAlias = mkIf (config.hostName != null && network != null) (mkOptionDefault system.access.fqdn);
            }
          ];
        }) config.networks;
      };
    };
  };
  sshModule = {
    lib,
    gensokyo-zone,
    osConfig,
    homeConfig,
    config,
    pkgs,
    ...
  }: let
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkMerge mkOptionDefault;
    inherit (lib.attrsets) mapAttrs mapAttrsToList;
    inherit (gensokyo-zone.lib) unmerged;
    inherit (osConfig.gensokyo-zone) access;
  in {
    options = with lib.types; {
      enable = mkEnableOption "ssh client configuration";
      user = mkOption {
        type = nullOr str;
        default = null;
      };
      hosts = mkOption {
        type = attrsOf (submoduleWith {
          modules = [ sshHostModule ];
          specialArgs = {
            inherit gensokyo-zone osConfig homeConfig pkgs;
          };
        });
      };
      networks = mkOption {
        type = listOf (nullOr str);
        default = [ null ];
      };
      proxyJump = mkOption {
        type = str;
      };
      extraOptions = mkOption {
        type = unmerged.types.attrs;
        default = {};
      };
      set = {
        matchBlocksSettings = mkOption {
          type = unmerged.types.attrs;
          default = {};
        };
      };
    };
    config = {
      proxyJump = mkOptionDefault (
        if config.hosts.hakurei.enable then config.hosts.hakurei.name
        else gensokyo-zone.systems.hakurei.config.access.fqdn
      );
      networks = mkOptionDefault [
        (mkIf access.local.enable "local")
        (mkIf access.tail.enabled "tail")
      ];
      hosts = mapAttrs (name: system: let
        enabled = system.config.access.online.enable && system.config.exports.services.sshd.enable;
      in mkIf enabled {
        systemName = mkOptionDefault name;
      }) gensokyo-zone.systems;
      set = {
        matchBlocksSettings = let
          mkMatchBlocksHost = host: mkIf host.enable (unmerged.mergeAttrs host.set.matchBlocksSettings);
        in mkMerge (
          mapAttrsToList (_: mkMatchBlocksHost) config.hosts
        );
      };
    };
  };
in {
  config,
  osConfig,
  lib,
  gensokyo-zone,
  pkgs,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf;
  inherit (gensokyo-zone.lib) unmerged;
  cfg = config.gensokyo-zone.ssh;
in {
  options.gensokyo-zone.ssh = mkOption {
    type = lib.types.submoduleWith {
      modules = [sshModule];
      specialArgs = {
        inherit gensokyo-zone pkgs;
        inherit osConfig;
        homeConfig = config;
      };
    };
    default = { };
  };

  config = {
    gensokyo-zone.ssh = {
    };
    programs.ssh = mkIf cfg.enable {
      matchBlocks = unmerged.mergeAttrs cfg.set.matchBlocksSettings;
    };
    lib.gensokyo-zone.ssh = {
      inherit cfg sshModule sshHostModule;
    };
  };
}
