{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkMerge mkIf;
  inherit (config.services) nginx;
  apartment = "5e85d878-c6b2-4b15-b803-9aeb63d63543";
  enableGrocy = false;
in {
  sops.secrets.cloudflared-tunnel-apartment.owner = "cloudflared";
  services.cloudflared = {
    tunnels = {
      ${apartment} = {
        credentialsFile = config.sops.secrets.cloudflared-tunnel-apartment.path;
        default = "http_status:404";
        ingress = mkMerge [
          (mkIf config.services.zigbee2mqtt.enable
            (nginx.virtualHosts.zigbee2mqtt.proxied.cloudflared.getIngress {})
          )
          (mkIf enableGrocy (mkMerge [
            (nginx.virtualHosts.grocy.proxied.cloudflared.getIngress {})
            (nginx.virtualHosts.barcodebuddy.proxied.cloudflared.getIngress {})
          ]))
          (mkIf config.services.home-assistant.enable
            (nginx.virtualHosts.home-assistant.proxied.cloudflared.getIngress {})
          )
          (nginx.virtualHosts.taskchampion.proxied.cloudflared.getIngress {})
        ];
      };
    };
  };
}
