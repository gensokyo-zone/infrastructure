{
  config,
  meta,
  lib,
  ...
}: {
  imports = with meta; [
    nixos.reisen-ct
    nixos.sops
    nixos.nginx
    nixos.cloudflared

    # media
    nixos.plex
    nixos.tautulli
    nixos.ombi
    nixos.deluge

    # yarr harr fiddle dee dee >w<
    nixos.radarr
    nixos.sonarr
    nixos.bazarr
    nixos.jackett
  ];

  sops.secrets.cloudflare_mediabox_tunnel = {
    owner = config.services.cloudflared.user;
  };

  services.cloudflared = let
    tunnelId = "6a3c1863-d879-462f-b5d5-7c6ddf476d0e";
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflare_mediabox_tunnel.path;
      ingress = {
        "plex.gensokyo.zone".service = "http://localhost:32400";
        "tauutuli.gensokyo.zone".service = "http://localhost:${toString config.services.tautulli.port}";
        "ombi.gensokyo.zone".service = "http://localhost:${toString config.services.ombi.port}";
        "sonarr.gensokyo.zone".service = "http://localhost:8989";
        "radarr.gensokyo.zone".service = "http://localhost:7878";
        "bazarr.gensokyo.zone".service = "http://localhost:6767";
        "jackett.gensokyo.zone".service = "http://localhost:9117";
        "deluge.gensokyo.zone".service = "http://localhost:${toString config.services.deluge.web.port}";
      };
    };
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "21.05";
}
