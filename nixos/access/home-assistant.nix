{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) home-assistant nginx;
  name.shortServer = mkDefault "home";
  listen' = {
    http = { };
    https.ssl = true;
    hass = {
      enable = !home-assistant.enable;
      port = mkDefault home-assistant.config.http.server_port;
      extraParameters = [ "default_server" ];
    };
  };
in {
  config.services.nginx.virtualHosts = {
    home-assistant = {
      inherit name;
      locations."/" = {
        proxy = {
          websocket.enable = true;
          headers.enableRecommended = true;
        };
        proxyPass = mkIf home-assistant.enable (mkDefault
          "http://localhost:${toString home-assistant.config.http.server_port}"
        );
      };
    };
    home-assistant'local = {
      inherit name listen';
      ssl.cert.copyFromVhost = "home-assistant";
      local.enable = mkDefault true;
      locations."/" = {
        proxy = {
          websocket.enable = true;
          headers.enableRecommended = true;
        };
        proxyPass = (mkDefault
          nginx.virtualHosts.home-assistant.locations."/".proxyPass
        );
      };
    };
  };
  config.networking.firewall.allowedTCPPorts = [ home-assistant.config.http.server_port ];
}
