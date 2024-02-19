{
  access,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) listToAttrs nameValuePair;
  inherit (access) systemFor;
  inherit (config.networking) hostName;
  cfg = config.services.cloudflared;
  apartment = "5e85d878-c6b2-4b15-b803-9aeb63d63543";
  accessHostFor = {
    hostName,
    system ? systemFor hostName,
    access ? "local",
    ...
  }: let
    host = system.networking.access.hostnameForNetwork.${access} or (throw "unsupported access ${access}");
  in
    if hostName == config.networking.hostName
    then "localhost"
    else host;
  ingressForNginx = {
    host ? system.networking.fqdn,
    port ? 80,
    hostName,
    system ? systemFor hostName,
  } @ args:
    nameValuePair host {
      service = "http://${accessHostFor args}:${toString port}";
    };
  ingressForHass = {
    host ? system.services.home-assistant.domain,
    port ? system.services.home-assistant.config.http.server_port,
    hostName,
    system ? systemFor hostName,
    ...
  } @ args:
    nameValuePair host {
      service = "http://${accessHostFor args}:${toString port}";
    };
  ingressForVouch = {
    host ? system.services.vouch-proxy.domain,
    port ? system.services.vouch-proxy.settings.vouch.port,
    hostName,
    system ? systemFor hostName,
    ...
  } @ args:
    nameValuePair host {
      service = "http://${accessHostFor args}:${toString port}";
    };
  ingressForKanidm = {
    host ? system.services.kanidm.server.frontend.domain,
    port ? system.services.kanidm.server.frontend.port,
    hostName,
    system ? systemFor hostName,
    ...
  } @ args:
    nameValuePair host {
      service = "https://${accessHostFor args}:${toString port}";
      originRequest.noTLSVerify = true;
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
            host = config.services.zigbee2mqtt.domain;
            inherit hostName;
          })
          (ingressForHass {inherit hostName;})
          (ingressForVouch {inherit hostName;})
          (ingressForKanidm {inherit hostName;})
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
