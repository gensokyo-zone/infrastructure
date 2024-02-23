{config, ...}: let
  inherit (config.services) deluge tautulli ombi sonarr radarr bazarr lidarr readarr prowlarr cloudflared;
in {
  sops.secrets.cloudflare_mediabox_tunnel = {
    owner = cloudflared.user;
  };

  services.cloudflared = let
    tunnelId = "6a3c1863-d879-462f-b5d5-7c6ddf476d0e";
    inherit (config.networking) domain;
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflare_mediabox_tunnel.path;
      ingress = {
        "tautulli.${domain}".service = "http://localhost:${toString tautulli.port}";
        "ombi.${domain}".service = "http://localhost:${toString ombi.port}";
        "sonarr.${domain}".service = "http://localhost:${toString sonarr.port}";
        "radarr.${domain}".service = "http://localhost:${toString radarr.port}";
        "bazarr.${domain}".service = "http://localhost:${toString bazarr.listenPort}";
        "lidarr.${domain}".service = "http://localhost:${toString lidarr.port}";
        "readarr.${domain}".service = "http://localhost:${toString readarr.port}";
        "prowlarr.${domain}".service = "http://localhost:${toString prowlarr.port}";
        "deluge.${domain}".service = "http://localhost:${toString deluge.web.port}";
      };
    };
  };
}
