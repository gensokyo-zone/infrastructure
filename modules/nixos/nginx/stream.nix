{
  gensokyo-zone,
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault;
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
    };

    config = {
      streamConfig = mkMerge [
        config.extraConfig
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
