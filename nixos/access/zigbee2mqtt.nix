{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.services.zigbee2mqtt;
in {
  services.nginx.virtualHosts.${cfg.domain} = {
    vouch.enable = true;
    locations = {
      "/" = {
        proxyPass = "http://127.0.0.1:${toString cfg.settings.frontend.port}";
        extraConfig = ''
          proxy_set_header Upgrade $http_upgrade;
          proxy_set_header Connection "upgrade";
          proxy_http_version 1.1;
        '';
      };
    };
  };
}
