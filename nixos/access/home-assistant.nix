{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (config.services) home-assistant nginx;
  name.shortServer = mkDefault "home";
  listenPorts = {
    http = { };
    https.ssl = true;
    hass = mkIf (!home-assistant.enable) { port = mkDefault home-assistant.config.http.server_port; };
  };
in {
  config.services.nginx.virtualHosts = {
    home-assistant = {
      inherit name listenPorts;
      locations."/".proxyPass = mkIf home-assistant.enable (mkDefault
        "http://localhost:${toString home-assistant.config.http.server_port}"
      );
    };
    home-assistant'local = {
      inherit name listenPorts;
      local.enable = mkDefault true;
      locations."/".proxyPass = mkIf home-assistant.enable (mkDefault
        nginx.virtualHosts.home-assistant.locations."/".proxyPass
      );
    };
  };
  config.networking.firewall.allowedTCPPorts = [ home-assistant.config.http.server_port ];
}
