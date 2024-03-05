{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  cfg = config.services.zigbee2mqtt;
  access = config.services.nginx.access.zigbee2mqtt;
  locations."/" = {
    proxy.websocket.enable = true;
    proxyPass = mkDefault "http://${access.host}:${toString access.port}";
  };
  name.shortServer = mkDefault "z2m";
in {
  options.services.nginx.access.zigbee2mqtt = with lib.types; {
    host = mkOption {
      type = str;
    };
    port = mkOption {
      type = port;
    };
  };
  config.services.nginx = {
    access.zigbee2mqtt = mkIf cfg.enable {
      host = mkOptionDefault "localhost";
      port = mkIf (cfg.settings ? frontend.port) (
        mkOptionDefault cfg.settings.frontend.port
      );
    };
    virtualHosts = {
      zigbee2mqtt = {
        inherit name locations;
        vouch.enable = true;
      };
      zigbee2mqtt'local = {
        inherit name locations;
        local.enable = true;
      };
    };
  };
}
