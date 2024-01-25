{
  config,
  meta,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.attrsets) mapAttrs mapAttrsToList;
  inherit (lib.strings) removePrefix;
  inherit (config.services) deluge plex tautulli ombi sonarr radarr bazarr lidarr readarr prowlarr cloudflared;
  kyuuto = "/mnt/kyuuto-media";
  kyuuto-library = kyuuto + "/library";
  plexLibrary = {
    "/mnt/Anime".hostPath = kyuuto-library + "/anime";
    "/mnt/Shows".hostPath = kyuuto-library + "/tv";
    "/mnt/Movies".hostPath = kyuuto-library + "/movies";
    "/mnt/Music".hostPath = kyuuto-library + "/music";
  };
in {
  imports = let
    inherit (meta) nixos;
  in [
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
    nixos.lidarr
    nixos.readarr
    nixos.prowlarr
  ];

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

  services.mediatomb = {
    serverName = "tewi";
    mediaDirectories = let
      mkLibraryDir = dir: {
        path = kyuuto-library + "/${dir}";
        mountPoint = kyuuto-library;
      };
      libraryDir = {
        path = kyuuto-library;
        mountPoint = kyuuto-library;
        subdirectories =
          mapAttrsToList (
            _: {hostPath, ...}:
              removePrefix "${kyuuto-library}/" hostPath
          )
          plexLibrary
          ++ ["tlmc" "music-raw"];
      };
    in
      [libraryDir] ++ map mkLibraryDir ["tlmc" "music-raw" "lewd"];
  };

  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [mesa.drivers vaapiVdpau libvdpau-va-gl];
  };

  fileSystems = let
    bind = {
      fsType = "none";
      options = ["bind" "nofail"];
    };
    fsPlex = mapAttrs (_: {hostPath, ...}:
      mkMerge [
        bind
        {
          device = hostPath;
        }
      ])
    plexLibrary;
    fsDeluge = {
      "${deluge.downloadDir}" = mkIf deluge.enable (mkMerge [
        bind
        {
          device = kyuuto + "/downloads/deluge/download";
        }
      ]);
    };
  in
    mkMerge [
      fsPlex
      (mkIf deluge.enable fsDeluge)
    ];

  systemd.services.deluged = mkIf deluge.enable {
    unitConfig.RequiresMountsFor = [
      "${deluge.downloadDir}"
    ];
  };
  systemd.services.plex = mkIf plex.enable {
    unitConfig.RequiresMountsFor = mapAttrsToList (path: _: path) plexLibrary;
  };

  systemd.network.networks.eth0 = {
    name = "eth0";
    matchConfig = {
      MACAddress = "BC:24:11:34:F4:A8";
      Type = "ether";
    };
    address = ["10.1.1.44/24"];
    gateway = ["10.1.1.1"];
    DHCP = "no";
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "21.05";
}
