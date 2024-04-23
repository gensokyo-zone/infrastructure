{
  gensokyo-zone,
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkAfter mkOptionDefault;
  inherit (lib.attrsets) mapAttrsToList;
  cfg = config.services.nginx.stream;
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
        ssl = {
          enable = mkEnableOption "ssl upstream";
          verify = mkEnableOption "proxy_ssl_verify";
        };
        url = mkOption {
          type = nullOr str;
          default = null;
        };
      };
    };

    config = {
      streamConfig = mkMerge [
        config.extraConfig
        (mkIf config.proxy.ssl.enable
          "proxy_ssl on;"
        )
        (mkIf (config.proxy.ssl.enable && config.proxy.ssl.verify)
          "proxy_ssl_verify on;"
        )
        (mkIf (config.proxy.url != null) (mkAfter
          "proxy_pass ${config.proxy.url};"
        ))
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
          inherit gensokyo-zone;
          nixosConfig = config;
        };
      });
      default = { };
    };
  };
  config.services.nginx = {
    streamConfig = mkMerge (
      mapAttrsToList (_: server: mkIf server.enable server.serverBlock) cfg.servers
    );
  };
}
