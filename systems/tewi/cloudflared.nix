{
  meta,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkMerge;
  inherit (lib.attrsets) listToAttrs nameValuePair;
  inherit (config.networking) hostName;
  cfg = config.services.cloudflared;
  apartment = "131222b0-9db0-4168-96f5-7d45ec51c3be";
  systemFor = hostName: if hostName == config.networking.hostName
    then config
    else meta.network.nodes.${hostName};
  accessHostFor = { hostName, access ? "local", ... }: let
    host = {
      local = "${hostName}.local";
      tail = "${hostName}.tail.cutie.moe";
    }.${access} or (throw "unsupported access ${access}");
  in if hostName == config.networking.hostName then "localhost" else host;
  ingressForNginx = { host ? system.networking.fqdn, port ? 80, hostName, system ? systemFor hostName }@args: nameValuePair host {
    service = "http://${accessHostFor args}:${toString port}";
  };
  ingressForHass = { host ? system.services.home-assistant.domain, port ? system.services.home-assistant.config.http.server_port, hostName, system ? systemFor hostName, ... }@args: nameValuePair host {
    service = "http://${accessHostFor args}:${toString port}";
  };
  ingressForVouch = { host ? system.services.vouch-proxy.domain, port ? system.services.vouch-proxy.settings.vouch.port, hostName, system ? systemFor hostName, ... }@args: nameValuePair host {
    service = "http://${accessHostFor args}:${toString port}";
  };
  ingressForKanidm = { host ? system.services.kanidm.server.frontend.domain, port ? system.services.kanidm.server.frontend.port, hostName, system ? systemFor hostName, ... }@args: nameValuePair host {
    service = "https://${accessHostFor args}:${toString port}";
    originRequest.noTLSVerify = true;
  };
  ingressForDeluge = { host, port ? system.services.deluge.web.port, hostName, system ? systemFor hostName, ... }@args: nameValuePair host {
    service = "http://${accessHostFor args}:${toString port}";
  };
in {
  sops.secrets.cloudflared-tunnel-apartment.owner = cfg.user;
  sops.secrets.cloudflared-tunnel-apartment-deluge.owner = cfg.user;
  services.cloudflared = {
    tunnels = {
      ${apartment} = {
        credentialsFile = config.sops.secrets.cloudflared-tunnel-apartment.path;
        default = "http_status:404";
        ingress = listToAttrs [
          (ingressForNginx { host = config.networking.domain; inherit hostName; })
          (ingressForNginx { host = config.services.zigbee2mqtt.domain; inherit hostName; })
          (ingressForHass { inherit hostName; })
          (ingressForVouch { inherit hostName; })
          (ingressForKanidm { inherit hostName; })
        ];
        extraTunnel.ingress = mkMerge [
          (listToAttrs [
            (ingressForDeluge { host = "deluge"; inherit hostName; })
          ])
          {
            deluge.hostname._secret = config.sops.secrets.cloudflared-tunnel-apartment-deluge.path;
          }
        ];
      };
    };
  };
}
