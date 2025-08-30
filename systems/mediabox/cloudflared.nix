{
  config,
  lib,
  ...
}: let
  inherit (config.services) nginx tautulli ombi sonarr radarr bazarr lidarr readarr prowlarr;
  inherit (lib.modules) mkMerge;
  inherit (lib.attrsets) mapAttrs' nameValuePair;
in {
  sops.secrets.cloudflare_mediabox_tunnel = {
    owner = "cloudflared";
  };

  services.cloudflared = let
    tunnelId = "6a3c1863-d879-462f-b5d5-7c6ddf476d0e";
    ingressPorts = {
      tautulli = tautulli.port;
      ombi = ombi.port;
      sonarr = sonarr.port;
      radarr = radarr.port;
      bazarr = bazarr.listenPort;
      lidarr = lidarr.port;
      readarr = readarr.port;
      prowlarr = prowlarr.port;
    };
    ingress = mapAttrs' (name: port:
      nameValuePair "${name}.${config.networking.domain}" {
        service = "http://localhost:${toString port}";
      })
    ingressPorts;
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflare_mediabox_tunnel.path;
      ingress = mkMerge [
        ingress
        (nginx.virtualHosts.deluge.proxied.cloudflared.getIngress {})
      ];
    };
  };
}
