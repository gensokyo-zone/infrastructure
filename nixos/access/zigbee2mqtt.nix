{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) nginx zigbee2mqtt;
  name.shortServer = mkDefault "z2m";
in {
  config.services.nginx = {
    virtualHosts = {
      zigbee2mqtt = {
        locations."/" = {
          proxy.websocket.enable = true;
          proxyPass = mkIf zigbee2mqtt.enable (
            mkDefault "http://localhost:${toString zigbee2mqtt.settings.frontend.port}"
          );
        };
        inherit name;
        vouch.enable = true;
      };
      zigbee2mqtt'local = {
        inherit name;
        ssl.cert.copyFromVhost = "zigbee2mqtt";
        locations."/" = {
          proxy.websocket.enable = true;
          proxyPass = mkDefault (
            nginx.virtualHosts.zigbee2mqtt.locations."/".proxyPass
          );
        };
        local.enable = true;
      };
    };
  };
}
