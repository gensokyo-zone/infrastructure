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
    tunnelId = "9295ed6e-4743-45c1-83b1-6c252ae5580a";
  in {
    tunnels.${tunnelId} = {
      default = "http_status:404";
      credentialsFile = config.sops.secrets.cloudflare_mediabox_tunnel.path;
      ingress = {
        "plex.gensokyo.zone".service = "http://localhost:32400";
        "tautuli.gensokyo.zone".service = "http://localhost:8181";
        "ombi.gensokyo.zone".service = "http://localhost:3579";
        "sonarr.gensokyo.zone".service = "http://localhost:8989";
        "radarr.gensokyo.zone".service = "http://localhost:7878";
        "bazarr.gensokyo.zone".service = "http://localhost:6767";
        "jackett.gensokyo.zone".service = "http://localhost:9117";
        "deluge.gensokyo.zone".service = "http://localhost:9117";
      };
    };
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "21.05";
}
