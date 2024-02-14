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
  inherit (config) kyuuto;
  plexLibrary = {
    "/mnt/Anime".hostPath = kyuuto.libraryDir + "/anime";
    "/mnt/Shows".hostPath = kyuuto.libraryDir + "/tv";
    "/mnt/Movies".hostPath = kyuuto.libraryDir + "/movies";
    "/mnt/Music".hostPath = kyuuto.libraryDir + "/music/assorted";
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
    ./cloudflared.nix

    # media
    nixos.kyuuto
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

  services.mediatomb = {
    serverName = "tewi";
    mediaDirectories = let
      mkLibraryDir = dir: {
        path = kyuuto.libraryDir + "/${dir}";
        mountPoint = kyuuto.libraryDir;
      };
      libraryDir = {
        path = kyuuto.libraryDir;
        mountPoint = kyuuto.libraryDir;
        subdirectories =
          mapAttrsToList (
            _: {hostPath, ...}:
              removePrefix "${kyuuto.libraryDir}/" hostPath
          )
          plexLibrary
          ++ ["tlmc" "music-raw"];
      };
    in
      [libraryDir] ++ map mkLibraryDir ["tlmc" "music-raw" "lewd"];
  };

  hardware.opengl = {
    enable = true;
    extraPackages = with pkgs; [mesa.drivers];
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
          device = kyuuto.mountDir + "/downloads/deluge/download";
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
