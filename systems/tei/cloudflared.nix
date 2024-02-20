{
  config,
  lib,
  access,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (config.services) home-assistant nginx;
  cfg = config.services.cloudflared;
  apartment = "5e85d878-c6b2-4b15-b803-9aeb63d63543";
  localNginx = "http://localhost:${toString nginx.defaultHTTPListenPort}";
in {
  sops.secrets.cloudflared-tunnel-apartment.owner = cfg.user;
  services.cloudflared = {
    tunnels = {
      ${apartment} = {
        credentialsFile = config.sops.secrets.cloudflared-tunnel-apartment.path;
        default = "http_status:404";
        ingress = {
          ${nginx.virtualHosts.zigbee2mqtt.serverName} = {
            service = localNginx;
          };
          ${nginx.virtualHosts.grocy.serverName} = {
            service = localNginx;
          };
          ${nginx.virtualHosts.barcodebuddy.serverName} = {
            service = localNginx;
          };
          ${home-assistant.domain} = assert home-assistant.enable; {
            service = access.proxyUrlFor { serviceName = "home-assistant"; };
          };
        };
      };
    };
  };

  systemd.services."cloudflared-tunnel-${apartment}" = rec {
    wants = mkIf config.services.tailscale.enable [
      "tailscaled.service"
    ];
    after = wants;
  };
}
