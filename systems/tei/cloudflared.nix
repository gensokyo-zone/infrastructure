{
  access,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) listToAttrs nameValuePair;
  inherit (access) nixosFor;
  inherit (config.networking) hostName;
  inherit (config.services) nginx;
  cfg = config.services.cloudflared;
  apartment = "5e85d878-c6b2-4b15-b803-9aeb63d63543";
  accessHostFor = {
    hostName,
    system ? nixosFor hostName,
    network ? "lan",
    ...
  }: let
    host = access.getHostnameFor hostName network;
  in
    if hostName == config.networking.hostName
    then "localhost"
    else host;
  ingressForNginx = {
    host ? system.networking.fqdn,
    port ? 80,
    hostName,
    system ? nixosFor hostName,
  } @ args:
    nameValuePair host {
      service = "http://${accessHostFor args}:${toString port}";
    };
  ingressForHass = {
    host ? system.services.home-assistant.domain,
    port ? system.services.home-assistant.config.http.server_port,
    hostName,
    system ? nixosFor hostName,
    ...
  } @ args:
    nameValuePair host {
      service = "http://${accessHostFor args}:${toString port}";
    };
in {
  sops.secrets.cloudflared-tunnel-apartment.owner = cfg.user;
  services.cloudflared = {
    tunnels = {
      ${apartment} = {
        credentialsFile = config.sops.secrets.cloudflared-tunnel-apartment.path;
        default = "http_status:404";
        ingress = listToAttrs [
          (ingressForNginx {
            host = nginx.virtualHosts.zigbee2mqtt.serverName;
            inherit hostName;
          })
          (ingressForNginx {
            host = nginx.virtualHosts.grocy.serverName;
            inherit hostName;
          })
          (ingressForNginx {
            host = nginx.virtualHosts.barcodebuddy.serverName;
            inherit hostName;
          })
          (ingressForHass {inherit hostName;})
        ];
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
