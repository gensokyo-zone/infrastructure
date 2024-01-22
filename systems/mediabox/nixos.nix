{
  config,
  meta,
  lib,
  pkgs,
  ...
}: {
  imports = with meta; [
    nixos.reisen-ct
    nixos.sops
    nixos.nginx
    nixos.access.plex
    nixos.cloudflared

    # media
    nixos.plex
    nixos.tautulli
    nixos.ombi
    nixos.deluge
    nixos.mediatomb

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
        "tautulli.gensokyo.zone".service = "http://localhost:${toString config.services.tautulli.port}";
        "ombi.gensokyo.zone".service = "http://localhost:${toString config.services.ombi.port}";
        "sonarr.gensokyo.zone".service = "http://localhost:8989";
        "radarr.gensokyo.zone".service = "http://localhost:7878";
        "bazarr.gensokyo.zone".service = "http://localhost:6767";
        "jackett.gensokyo.zone".service = "http://localhost:9117";
        "deluge.gensokyo.zone".service = "http://localhost:${toString config.services.deluge.web.port}";
      };
    };
  };

  services.mediatomb = {
    serverName = "tewi";
    mediaDirectories = [
      rec {
        path = "/mnt/Anime";
        mountPoint = path;
      }
      rec {
        path = "/mnt/Shows";
        mountPoint = path;
      }
      rec {
        path = "/mnt/Movies";
        mountPoint = path;
      }
    ];
  };

  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [ mesa.drivers vaapiVdpau libvdpau-va-gl ];
  };

  systemd.network.networks.eth0 = {
    name = "eth0";
    matchConfig = {
      MACAddress = "BC:24:11:34:F4:A8";
      Type = "ether";
    };
    address = [ "10.1.1.44/24" ];
    gateway = [ "10.1.1.1" ];
    DHCP = "no";
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "21.05";
}
