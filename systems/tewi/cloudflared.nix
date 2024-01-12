{
  config,
  lib,
  ...
}: let
  inherit (config) services;
  apartment = "131222b0-9db0-4168-96f5-7d45ec51c3be";
in {
  sops.secrets.cloudflared-tunnel-apartment.owner = services.cloudflared.user;
  sops.secrets.cloudflared-tunnel-apartment-deluge.owner = services.cloudflared.user;
  services.cloudflared = {
    tunnels = {
      ${apartment} = {
        credentialsFile = config.sops.secrets.cloudflared-tunnel-apartment.path;
        default = "http_status:404";
        ingress = {
          ${config.networking.domain}.service = "http://localhost:80";
          ${services.home-assistant.domain}.service = "http://localhost:${toString services.home-assistant.config.http.server_port}";
          ${services.zigbee2mqtt.domain}.service = "http://localhost:80";
          ${services.vouch-proxy.domain}.service = "http://localhost:${toString services.vouch-proxy.settings.vouch.port}";
          ${services.kanidm.server.frontend.domain} = {
            service = "https://127.0.0.1:${toString services.kanidm.server.frontend.port}";
            originRequest.noTLSVerify = true;
          };
        };
        extraTunnel.ingress = {
          deluge = {
            hostname._secret = config.sops.secrets.cloudflared-tunnel-apartment-deluge.path;
            service = "http://localhost:${toString services.deluge.web.port}";
          };
        };
      };
    };
  };
}
