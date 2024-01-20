{
  config,
  lib,
  ...
}:
let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  cfg = config.services.zigbee2mqtt;
  access = config.services.nginx.access.zigbee2mqtt;
  proxyPass = mkDefault "http://${access.host}:${toString access.port}";
  extraConfig = ''
    proxy_set_header Upgrade $http_upgrade;
    proxy_set_header Connection "upgrade";
    proxy_http_version 1.1;
  '';
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
        locations."/" = {
          inherit proxyPass extraConfig;
        };
      };
      ${access.localDomain} = {
        local.enable = true;
        locations."/" = {
          inherit proxyPass extraConfig;
        };
      };
      "z2m.tail.${config.networking.domain}" = mkIf config.services.tailscale.enable {
        local.enable = true;
        locations."/" = {
          inherit proxyPass extraConfig;
        };
      };
    };
  };
}
