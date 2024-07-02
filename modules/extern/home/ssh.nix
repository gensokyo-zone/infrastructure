let
  sshHostNetworkModule = {
    lib,
    gensokyo-zone,
    osConfig,
    homeConfig,
    sshHostConfig,
    config,
    name,
    ...
  }: let
    inherit (gensokyo-zone.lib) unmerged mkAlmostOptionDefault;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkOptionDefault mkDefault;
    inherit (lib.lists) head optional;
  in {
    options = with lib.types; {
      enable =
        mkEnableOption "ssh match block configuration"
        // {
          default = true;
        };
      name = mkOption {
        type = str;
      };
      network = mkOption {
        type = nullOr str;
        default = null;
      };
      hostName = mkOption {
        type = str;
      };
      hostKeyAlias = mkOption {
        type = nullOr str;
      };
      port = mkOption {
        type = port;
      };
      proxyJump = mkOption {
        type = nullOr str;
        default = null;
      };
      matchBlockSettings = mkOption {
        type = unmerged.types.attrs;
      };
    };
    config = let
      system = gensokyo-zone.systems.${sshHostConfig.systemName};
    in {
      port = let
        inherit (system.exports.services) sshd;
        port = head (
          optional (config.network == null && sshd.ports.global.enable or false) sshd.ports.global.port
          ++ optional (sshd.ports.public.enable or false) sshd.ports.public.port
          ++ [sshd.ports.standard.port]
        );
      in mkOptionDefault port;
      hostName = let
        hostName = if config.network != null
          then system.network.networks.${config.network}.fqdn
          else sshHostConfig.hostName;
      in mkOptionDefault hostName;
      hostKeyAlias = mkOptionDefault sshHostConfig.hostKeyAlias;
      matchBlockSettings = {
        hostname = mkDefault config.hostName;
        port = mkIf (config.port != 22) (mkDefault config.port);
        proxyJump = mkIf (config.proxyJump != null) (mkAlmostOptionDefault config.proxyJump);
        extraOptions = {
          HostKeyAlias = mkIf (config.hostKeyAlias != null && config.hostKeyAlias != config.hostName) (mkOptionDefault config.hostKeyAlias);
        };
      };
    };
  };
  sshHostModule = {
    lib,
    pkgs,
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
    inherit (lib.lists) head elem filter unique intersectLists;
    inherit (lib.attrsets) filterAttrs mapAttrs' mapAttrsToList nameValuePair;
    inherit (lib.strings) optionalString;
    inherit (osConfig.gensokyo-zone) access;
    cfg = gensokyo-zone.ssh.cfg;
    system = gensokyo-zone.systems.${config.systemName};
    networks = let
      fallbackNetwork =
        if system.network.networks.local.enable or false && access.local.enable
        then "local"
        else if system.access.global.enable
        then null
        else if system.network.networks.int.enable or false
        then "int"
        else if system.network.networks.local.enable or false
        then "local"
        else null;
      networks = map (name: coalesce [name fallbackNetwork]) config.networks;
    in
      unique networks;
  in {
    options = with lib.types; {
      enable =
        mkEnableOption "ssh client configuration"
        // {
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
      networks' = mkOption {
        type = attrsOf (submoduleWith {
          modules = [sshHostNetworkModule];
          specialArgs = {
            inherit gensokyo-zone osConfig homeConfig pkgs;
            sshHostConfig = config;
          };
        });
      };
      hostName = mkOption {
        type = nullOr str;
      };
      hostKeyAlias = mkOption {
        type = nullOr str;
      };
      extraOptions = mkOption {
        type = unmerged.types.attrs;
      };
      extraSettings = mkOption {
        type = unmerged.types.attrs;
        default = {};
      };
      set = {
        matchBlockSettings = mkOption {
          type = unmerged.types.attrs;
          default = {};
        };
        matchBlocksSettings = mkOption {
          type = unmerged.types.attrs;
          default = {};
        };
      };
    };
    config = {
      hostName = mkOptionDefault system.access.fqdn;
      hostKeyAlias = mkOptionDefault system.access.fqdn;
      extraOptions = mkOptionDefault (unmerged.mergeAttrs cfg.extraOptions);
      user = mkIf (config.systemName == "u7pro") (mkAlmostOptionDefault "kittywitch");
      networks = let
        enabledNetworks = filterAttrs (_: net: net.enable) system.network.networks;
        networkNames = mapAttrsToList (_: net: net.name) enabledNetworks;
        networks = filter (name: name == null || elem name networkNames) cfg.networks;
      in
        mkOptionDefault networks;
      networks' = let
        canonNetworkName' = intersectLists networks [null "int" "local"];
        canonNetworkName =
          if canonNetworkName' != []
          then head canonNetworkName'
          else null;
        mkNetwork = network: nameValuePair (mkNetworkName network) (mkNetworkConf network);
        mkNetworkName = network: if network != null then network else "fallback";
        mkNetworkConf = network: let
          needsProxy = network == "int" || (network == "local" && !access.local.enable);
          networkConf = {
            network = mkAlmostOptionDefault network;
            name = mkAlmostOptionDefault (config.name + optionalString (network != canonNetworkName) "-${network}");
            proxyJump = mkIf needsProxy (lib.warnIf (config.name == cfg.proxyJump) "proxyJump self-reference" (mkAlmostOptionDefault (
              cfg.proxyJump
            )));
          };
        in networkConf;
      in
        mapListToAttrs mkNetwork networks;
      set = {
        matchBlockSettings = let
          matchBlock = {
            user = mkIf (config.user != null) (mkDefault config.user);
            identitiesOnly = mkIf (config.systemName == "u7pro") (mkAlmostOptionDefault true);
            extraOptions = unmerged.mergeAttrs config.extraOptions;
          };
          extraSettings = unmerged.mergeAttrs config.extraSettings;
        in mkMerge [ matchBlock extraSettings ];
        matchBlocksSettings = let
          mkMatchBlock = _: network: let
            matchBlockConf = mkMerge [
              (unmerged.mergeAttrs network.matchBlockSettings)
              (unmerged.mergeAttrs config.set.matchBlockSettings)
            ];
          in
            nameValuePair network.name matchBlockConf;
        in
          mapAttrs' mkMatchBlock config.networks';
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
    inherit (lib.lists) elem;
    inherit (gensokyo-zone.lib) unmerged mkAlmostOptionDefault;
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
          modules = [sshHostModule];
          specialArgs = {
            inherit gensokyo-zone osConfig homeConfig pkgs;
          };
        });
      };
      networks = mkOption {
        type = listOf (nullOr str);
        default = [null];
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
        if config.hosts.hakurei.enable
        then config.hosts.hakurei.name
        else gensokyo-zone.systems.hakurei.access.fqdn
      );
      networks = mkOptionDefault [
        (mkIf access.local.enable "local")
        (mkIf access.tail.enabled "tail")
      ];
      hosts = mapAttrs (name: system:
        mkIf (elem system.type ["NixOS" "MacOS" "Linux" "Darwin"]) {
          enable = mkAlmostOptionDefault (system.access.online.enable && system.exports.services.sshd.enable);
          systemName = mkOptionDefault name;
        })
      gensokyo-zone.systems;
      set = {
        matchBlocksSettings = let
          mkMatchBlocksHost = host: mkIf host.enable (unmerged.mergeAttrs host.set.matchBlocksSettings);
        in
          mkMerge (
            mapAttrsToList (_: mkMatchBlocksHost) config.hosts
          );
      };
    };
  };
in
  {
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
      default = {};
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
