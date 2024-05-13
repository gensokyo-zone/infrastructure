{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) nginx zigbee2mqtt;
  upstreamName = "zigbee2mqtt'access";
in {
  config.services.nginx = {
    vouch.enable = mkIf nginx.virtualHosts.zigbee2mqtt.enable true;
    upstreams'.${upstreamName}.servers = {
      local = {
        enable = mkDefault zigbee2mqtt.enable;
        addr = mkDefault "localhost";
        port = mkIf zigbee2mqtt.enable (mkDefault zigbee2mqtt.settings.frontend.port);
      };
      service = {upstream, ...}: {
        enable = mkIf upstream.servers.local.enable (mkDefault false);
        accessService = {
          name = "zigbee2mqtt";
        };
      };
    };
    virtualHosts = let
      locations = {
        "/" = {
          proxy.enable = true;
        };
        "/api" = {
          proxy = {
            enable = true;
            websocket.enable = true;
          };
        };
      };
      name.shortServer = mkDefault "z2m";
      copyFromVhost = mkDefault "zigbee2mqtt";
    in {
      zigbee2mqtt = {
        proxy = {
          upstream = mkDefault upstreamName;
        };
        inherit name locations;
        vouch.enable = true;
      };
      zigbee2mqtt'local = {
        inherit name locations;
        ssl.cert = {
          inherit copyFromVhost;
        };
        proxy = {
          inherit copyFromVhost;
        };
        local.enable = true;
      };
    };
  };
}
