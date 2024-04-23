let
  serverModule = {config, nixosConfig, name, gensokyo-zone, lib, ...}: let
    inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkBefore mkOptionDefault;
    inherit (lib.attrsets) mapAttrsToList;
    inherit (lib.lists) optional;
    inherit (lib.strings) concatStringsSep replaceStrings;
    cfg = config.ssl.preread;
    inherit (nixosConfig.services) nginx;
  in {
    options.ssl.preread = with lib.types; {
      enable = mkEnableOption "ngx_stream_ssl_preread_module";
      upstream = mkOption {
        type = str;
        default = "$preread_" + replaceStrings [ "'" ] [ "_" ] name;
      };
      upstreams = mkOption {
        type = nullOr (attrsOf str);
      };
      streamConfig = mkOption {
        type = lines;
      };
    };
    config = let
      inherit (nginx.stream) upstreams;
      mkUpstream = host: upstream: "${host} ${upstreams.${upstream}.name};";
      upstreams' = removeAttrs cfg.upstreams [ "default" ];
      upstreamLines = mapAttrsToList mkUpstream upstreams'
      ++ optional (cfg.upstreams ? default) (mkUpstream "default" cfg.upstreams.default);
    in {
      ssl.preread = {
        streamConfig = mkIf (cfg.upstreams != null) ''
          map $ssl_preread_server_name ${cfg.upstream} {
            hostnames;
            ${concatStringsSep "\n  " upstreamLines}
          }
        '';
      };
      proxy = mkIf cfg.enable {
        enable = mkAlmostOptionDefault true;
        ssl.enable = false;
        upstream = mkAlmostOptionDefault cfg.upstream;
      };
      streamConfig = mkIf cfg.enable "ssl_preread on;";
      serverBlock = mkIf cfg.enable (mkOptionDefault (mkBefore cfg.streamConfig));
    };
  };
in {config, gensokyo-zone, lib, ...}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  cfg = config.services.nginx.ssl.preread;
in {
  options.services.nginx = with lib.types; {
    ssl.preread = {
      enable = mkEnableOption "ssl preread";
      listenPort = mkOption {
        type = port;
        default = 444;
      };
      serverPort = mkOption {
        type = port;
        default = 443;
      };
      serverName = mkOption {
        type = str;
        default = "preread'https";
      };
      upstreamName = mkOption {
        type = str;
        default = "preread'nginx";
      };
    };
    stream.servers = mkOption {
      type = attrsOf (submoduleWith {
        modules = [serverModule];
        shorthandOnlyDefinesConfig = false;
      });
    };
  };
  config = {
    services.nginx = {
      defaultSSLListenPort = mkIf cfg.enable cfg.listenPort;
      stream = {
        upstreams.${cfg.upstreamName} = mkIf cfg.enable {
          ssl.enable = true;
          servers.access = {
            addr = mkDefault "localhost";
            port = mkOptionDefault cfg.listenPort;
          };
        };
        servers.${cfg.serverName} = {
          enable = mkIf (!cfg.enable) (mkAlmostOptionDefault false);
          listen.https.port = cfg.serverPort;
          ssl.preread = {
            enable = true;
            upstreams.default = mkOptionDefault cfg.upstreamName;
          };
        };
      };
    };
  };
}
