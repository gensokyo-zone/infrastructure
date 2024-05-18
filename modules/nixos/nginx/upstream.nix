let
  upstreamServerAccessModule = {
    config,
    nixosConfig,
    name,
    gensokyo-zone,
    lib,
    upstreamKind,
    ...
  }: let
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkIf mkMerge mkOptionDefault;
    inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
    inherit (lib.attrsets) attrValues;
    inherit (lib.lists) findSingle;
    inherit (lib.trivial) mapNullable;
    inherit (nixosConfig.lib) access;
    cfg = config.accessService;
    system = access.systemFor cfg.system;
    service = system.exports.services.${cfg.name};
    port = service.ports.${cfg.port};
  in {
    options = with lib.types; {
      accessService = {
        enable = mkOption {
          type = bool;
        };
        name = mkOption {
          type = nullOr str;
          default = null;
        };
        system = mkOption {
          type = nullOr str;
        };
        id = mkOption {
          type = nullOr str;
          default = null;
        };
        port = mkOption {
          type = str;
          default = "default";
        };
        getAddressFor = mkOption {
          type = str;
          default = "getAddressFor";
        };
        network = mkOption {
          type = str;
          default = "lan";
        };
      };
    };
    config = let
      confAccess.accessService = {
        enable = mkOptionDefault (cfg.id != null || cfg.name != null);
        name = mkIf (cfg.id != null) (mkAlmostOptionDefault (
          (findSingle (s: s.id == cfg.id) null null (attrValues system.exports.services)).name
        ));
        system = mkMerge [
          (mkIf (cfg.id != null) (mkAlmostOptionDefault (access.systemForServiceId cfg.id).name))
          (mkOptionDefault (mapNullable (serviceName: (access.systemForService serviceName).name) cfg.name))
        ];
      };
      conf = {
        enable = lib.warnIf (!port.enable) "${cfg.system}.exports.services.${cfg.name}.ports.${cfg.port} isn't enabled" (
          mkAlmostOptionDefault port.enable
        );
        addr = mkAlmostOptionDefault (access.${cfg.getAddressFor} system.name cfg.network);
        port = mkOptionDefault port.port;
        ssl.enable = mkIf port.ssl (mkAlmostOptionDefault true);
      };
    in
      mkMerge [
        confAccess
        (mkIf cfg.enable conf)
      ];
  };
  upstreamServerModule = {
    config,
    name,
    gensokyo-zone,
    lib,
    upstreamKind,
    ...
  }: let
    inherit (gensokyo-zone.lib) mkAddress6;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkMerge mkBefore mkOptionDefault;
    inherit (lib.attrsets) mapAttrsToList;
    inherit (lib.lists) optional;
    inherit (lib.strings) optionalString;
    inherit (lib.trivial) isBool;
  in {
    options = with lib.types; {
      enable =
        mkEnableOption "upstream server"
        // {
          default = true;
        };
      addr = mkOption {
        type = str;
        default = name;
      };
      port = mkOption {
        type = nullOr port;
      };
      ssl = {
        enable = mkEnableOption "ssl upstream server";
      };
      server = mkOption {
        type = str;
        example = "unix:/tmp/backend3";
      };
      settings = mkOption {
        type = attrsOf (oneOf [int str bool]);
        default = {};
      };
      extraConfig = mkOption {
        type = str;
        default = "";
      };
      serverConfig = mkOption {
        type = separatedString " ";
        internal = true;
      };
      serverDirective = mkOption {
        type = str;
        internal = true;
      };
    };
    config = let
      mapSetting = key: value:
        if isBool value
        then mkIf value key
        else "${key}=${toString value}";
      settings = mapAttrsToList mapSetting config.settings;
      port = optionalString (config.port != null) ":${toString config.port}";
    in {
      server = mkOptionDefault "${mkAddress6 config.addr}${port}";
      serverConfig = mkMerge (
        [(mkBefore config.server)]
        ++ settings
        ++ optional (config.extraConfig != "") config.extraConfig
      );
      serverDirective = mkOptionDefault "server ${config.serverConfig};";
    };
  };
  upstreamModule = {
    config,
    name,
    nixosConfig,
    gensokyo-zone,
    lib,
    upstreamKind,
    ...
  }: let
    inherit (gensokyo-zone.lib) mkAlmostOptionDefault unmerged;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkMerge mkOptionDefault;
    inherit (lib.attrsets) filterAttrs attrNames attrValues mapAttrsToList mapAttrs' nameValuePair;
    inherit (lib.lists) findSingle any;
    inherit (lib.strings) replaceStrings;
  in {
    options = with lib.types; let
      upstreamServer = submoduleWith {
        modules = [upstreamServerModule upstreamServerAccessModule];
        specialArgs = {
          inherit nixosConfig gensokyo-zone upstreamKind;
          upstream = config;
        };
      };
    in {
      enable =
        mkEnableOption "upstream block"
        // {
          default = true;
        };
      name = mkOption {
        type = str;
        default = replaceStrings ["'"] ["_"] name;
      };
      servers = mkOption {
        type = attrsOf upstreamServer;
      };
      host = mkOption {
        type = nullOr str;
        default = null;
      };
      ssl = {
        enable = mkEnableOption "ssl upstream";
        host = mkOption {
          type = nullOr str;
          default = null;
        };
      };
      defaultServerName = mkOption {
        type = nullOr str;
      };
      extraConfig = mkOption {
        type = lines;
        default = "";
      };
      upstreamConfig = mkOption {
        type = lines;
        internal = true;
      };
      upstreamBlock = mkOption {
        type = lines;
        internal = true;
      };
      upstreamSettings = mkOption {
        type = unmerged.types.attrs;
        internal = true;
      };
    };

    config = let
      enabledServers = filterAttrs (_: server: server.enable) config.servers;
      assertServers = v: assert enabledServers != {}; v;
    in {
      ssl.enable = mkIf (any (server: server.ssl.enable) (attrValues enabledServers)) (mkAlmostOptionDefault true);
      defaultServerName = findSingle (_: true) null null (attrNames enabledServers);
      upstreamConfig = mkMerge (
        mapAttrsToList (_: server: mkIf server.enable server.serverDirective) config.servers
        ++ [config.extraConfig]
      );
      upstreamBlock = mkOptionDefault ''
        upstream ${config.name} {
          ${assertServers config.upstreamConfig}
        }
      '';
      upstreamSettings = assertServers (mkOptionDefault {
        #extraConfig = config.upstreamConfig;
        extraConfig = config.extraConfig;
        servers = mapAttrs' (name: server:
          nameValuePair (
            if server.enable
            then server.server
            else "disabled_${name}"
          ) (mkIf server.enable (mkMerge [
            server.settings
            (mkIf (server.extraConfig != "") {
              ${config.extraConfig} = true;
            })
          ])))
        config.servers;
      });
    };
  };
  serverModule = {
    config,
    nixosConfig,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkIf;
    inherit (lib.strings) hasPrefix;
    inherit (nixosConfig.services) nginx;
  in {
    options = with lib.types; {
      proxy = {
        upstream = mkOption {
          type = nullOr str;
          default = null;
        };
      };
    };

    config = let
      proxyUpstream = nginx.stream.upstreams.${config.proxy.upstream};
      dynamicUpstream = hasPrefix "$" config.proxy.upstream;
      hasUpstream = config.proxy.upstream != null && !dynamicUpstream;
      proxyPass =
        if dynamicUpstream
        then config.proxy.upstream
        else assert proxyUpstream.enable; proxyUpstream.name;
    in {
      proxy = {
        enable = mkIf (config.proxy.upstream != null) true;
        url = mkIf (config.proxy.upstream != null) (mkAlmostOptionDefault proxyPass);
        ssl = mkIf (hasUpstream && proxyUpstream.ssl.enable) {
          enable = mkAlmostOptionDefault true;
          host = mkAlmostOptionDefault proxyUpstream.ssl.host;
        };
      };
    };
  };
  proxyUpstreamModule = {
    config,
    nixosConfig,
    lib,
    ...
  }: let
    inherit (lib.options) mkOption;
  in {
    options = with lib.types; {
      proxy = {
        upstream = mkOption {
          type = nullOr str;
        };
      };
    };
  };
  locationModule = {
    config,
    nixosConfig,
    virtualHost,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
    inherit (lib.modules) mkIf mkOptionDefault;
    inherit (lib.strings) hasPrefix;
    inherit (nixosConfig.services) nginx;
  in {
    imports = [proxyUpstreamModule];

    config = let
      proxyUpstream = nginx.upstreams'.${config.proxy.upstream};
      proxyScheme =
        if config.proxy.ssl.enable
        then "https"
        else "http";
      dynamicUpstream = hasPrefix "$" config.proxy.upstream;
      hasUpstream = config.proxy.upstream != null && !dynamicUpstream;
      proxyHost =
        if dynamicUpstream
        then config.proxy.upstream
        else assert proxyUpstream.enable; proxyUpstream.name;
    in {
      proxy = {
        upstream = mkOptionDefault virtualHost.proxy.upstream;
        enable = mkIf (config.proxy.upstream != null && virtualHost.proxy.upstream == null) true;
        url = mkIf (config.proxy.upstream != null) (
          mkAlmostOptionDefault
          "${proxyScheme}://${proxyHost}"
        );
        ssl = {
          enable = mkAlmostOptionDefault (
            if hasUpstream
            then proxyUpstream.ssl.enable
            else false
          );
          host = mkIf hasUpstream (mkAlmostOptionDefault proxyUpstream.ssl.host);
        };
        host = mkIf (hasUpstream && proxyUpstream.host != null) (mkAlmostOptionDefault proxyUpstream.host);
      };
    };
  };
  hostModule = {
    config,
    nixosConfig,
    lib,
    ...
  }: let
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkOptionDefault;
  in {
    imports = [proxyUpstreamModule];

    options = with lib.types; {
      locations = mkOption {
        type = attrsOf (submodule locationModule);
      };
    };

    config = {
      proxy = {
        upstream = mkOptionDefault null;
      };
    };
  };
in
  {
    config,
    lib,
    gensokyo-zone,
    ...
  }: let
    inherit (gensokyo-zone.lib) unmerged;
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkIf mkMerge;
    inherit (lib.attrsets) mapAttrsToList;
    cfg = config.services.nginx;
  in {
    options.services.nginx = with lib.types; {
      upstreams' = mkOption {
        type = attrsOf (submoduleWith {
          modules = [upstreamModule];
          shorthandOnlyDefinesConfig = false;
          specialArgs = {
            inherit gensokyo-zone;
            nixosConfig = config;
            upstreamKind = "virtualHost";
          };
        });
        default = {};
      };
      virtualHosts = mkOption {
        type = attrsOf (submodule hostModule);
      };
      stream = {
        upstreams = mkOption {
          type = attrsOf (submoduleWith {
            modules = [upstreamModule];
            shorthandOnlyDefinesConfig = false;
            specialArgs = {
              inherit gensokyo-zone;
              nixosConfig = config;
              upstreamKind = "stream";
            };
          });
          default = {};
        };
        servers = mkOption {
          type = attrsOf (submoduleWith {
            modules = [serverModule];
            shorthandOnlyDefinesConfig = false;
          });
        };
      };
    };
    config.services.nginx = let
      confStream.streamConfig = mkMerge (
        mapAttrsToList (_: upstream: mkIf upstream.enable upstream.upstreamBlock) cfg.stream.upstreams
      );
      useUpstreams = true;
      confUpstreams.upstreams = mkMerge (mapAttrsToList (_: upstream:
        mkIf upstream.enable {
          ${upstream.name} = unmerged.mergeAttrs upstream.upstreamSettings;
        })
      cfg.upstreams');
      confBlock.commonHttpConfig = mkMerge (
        mapAttrsToList (_: upstream: mkIf upstream.enable upstream.upstreamBlock) cfg.upstreams'
      );
    in
      mkMerge [
        confStream
        (
          if useUpstreams
          then confUpstreams
          else confBlock
        )
      ];
  }
