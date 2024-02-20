{
  config,
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAddress6;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkOptionDefault;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) optional;
  cfg = config.services.nginx.stream;
  upstreamServerModule = {config, name, ...}: {
    options = with lib.types; {
      enable = mkEnableOption "upstream server" // {
        default = true;
      };
      addr = mkOption {
        type = str;
        default = name;
      };
      port = mkOption {
        type = port;
      };
      server = mkOption {
        type = str;
        example = "unix:/tmp/backend3";
      };
      settings = mkOption {
        type = attrsOf (oneOf [ int str ]);
        default = { };
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
      settings = mapAttrsToList (key: value: "${key}=${toString value}") config.settings;
    in {
      server = mkOptionDefault "${mkAddress6 config.addr}:${toString config.port}";
      serverConfig = mkMerge (
        [ (mkBefore config.server) ]
        ++ settings
        ++ optional (config.extraConfig != "") config.extraConfig
      );
      serverDirective = mkOptionDefault "server ${config.serverConfig};";
    };
  };
  upstreamModule = {config, name, nixosConfig, ...}: {
    options = with lib.types; let
      upstreamServer = submoduleWith {
        modules = [ upstreamServerModule ];
        specialArgs = {
          inherit nixosConfig;
          upstream = config;
        };
      };
    in {
      enable = mkEnableOption "upstream block" // {
        default = true;
      };
      name = mkOption {
        type = str;
        default = name;
      };
      servers = mkOption {
        type = attrsOf upstreamServer;
      };
      ssl = {
        enable = mkEnableOption "ssl upstream";
      };
      extraConfig = mkOption {
        type = lines;
        default = "";
      };
      streamConfig = mkOption {
        type = lines;
        internal = true;
      };
      upstreamBlock = mkOption {
        type = lines;
        internal = true;
      };
    };

    config = {
      streamConfig = mkMerge (
        mapAttrsToList (_: server: mkIf server.enable server.serverDirective) config.servers
        ++ [ config.extraConfig ]
      );
      upstreamBlock = mkOptionDefault ''
        upstream ${config.name} {
          ${config.streamConfig}
        }
      '';
    };
  };
  serverModule = {config, ...}: {
    options = with lib.types; {
      enable = mkEnableOption "stream server block" // {
        default = true;
      };
      extraConfig = mkOption {
        type = lines;
        default = "";
      };
      streamConfig = mkOption {
        type = lines;
        internal = true;
      };
      serverBlock = mkOption {
        type = lines;
        internal = true;
      };
      proxy = {
        upstream = mkOption {
          type = nullOr str;
          default = null;
        };
        url = mkOption {
          type = nullOr str;
        };
      };
    };

    config = {
      proxy = {
        url = mkOptionDefault (
          if config.proxy.upstream != null then cfg.upstreams.${config.proxy.upstream}.name
          else null
        );
      };
      streamConfig = let
        proxyUpstream = cfg.upstreams.${config.proxy.upstream};
      in mkMerge [
        config.extraConfig
        (mkIf (config.proxy.upstream != null && proxyUpstream.ssl.enable) ''
          proxy_ssl on;
          proxy_ssl_verify off;
        '')
        (mkIf (config.proxy.url != null) ''
          proxy_pass ${config.proxy.url};
        '')
      ];
      serverBlock = mkOptionDefault ''
        server {
          ${config.streamConfig}
        }
      '';
    };
  };
in {
  options.services.nginx.stream = with lib.types; {
    servers = mkOption {
      type = attrsOf (submoduleWith {
        modules = [serverModule];
        shorthandOnlyDefinesConfig = false;
        specialArgs = {
          nixosConfig = config;
        };
      });
      default = { };
    };
    upstreams = mkOption {
      type = attrsOf (submoduleWith {
        modules = [upstreamModule];
        shorthandOnlyDefinesConfig = false;
        specialArgs = {
          nixosConfig = config;
        };
      });
      default = { };
    };
  };
  config.services.nginx = {
    streamConfig = mkMerge (
      mapAttrsToList (_: upstream: mkIf upstream.enable upstream.upstreamBlock) cfg.upstreams
      ++ mapAttrsToList (_: server: mkIf server.enable server.serverBlock) cfg.servers
    );
  };
}
