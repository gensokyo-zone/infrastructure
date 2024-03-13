{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  cfg = config.services.zigbee2mqtt;
  access = config.services.nginx.access.zigbee2mqtt;
  location = {
    proxy.websocket.enable = true;
    proxyPass = mkDefault "http://${access.host}:${toString access.port}";
  };
in {
  options.services.nginx.access.zigbee2mqtt = with lib.types; {
    host = mkOption {
      type = str;
    };
    domain = mkOption {
      type = str;
    };
    localDomain = mkOption {
      type = str;
      default = "z2m.local.${config.networking.domain}";
    };
    tailDomain = mkOption {
      type = str;
      default = "z2m.tail.${config.networking.domain}";
    };
    port = mkOption {
      type = port;
    };
  };
  config.services.nginx = {
    access.zigbee2mqtt = mkIf cfg.enable {
      domain = mkOptionDefault cfg.domain;
      host = mkOptionDefault "localhost";
      port = mkIf (cfg.settings ? frontend.port) (
        mkOptionDefault cfg.settings.frontend.port
      );
    };
    virtualHosts = {
      ${access.domain} = {
        vouch.enable = true;
        locations."/" = location;
      };
      ${access.localDomain} = {
        serverAliases = mkIf config.services.tailscale.enable [access.tailDomain];
        local.enable = true;
        locations."/" = location;
      };
    };
  };
}
