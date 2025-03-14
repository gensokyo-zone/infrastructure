{
  config,
  gensokyo-zone,
  meta,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.attrsets) mapAttrs mapAttrsToList;
  inherit (lib.strings) removePrefix;
  inherit (config.services) deluge plex;
  inherit (config) kyuuto;
  plexLibrary = {
    "/mnt/Anime".hostPath = kyuuto.libraryDir + "/anime";
    "/mnt/Shows".hostPath = kyuuto.libraryDir + "/tv";
    "/mnt/Movies".hostPath = kyuuto.libraryDir + "/movies";
    "/mnt/Music".hostPath = kyuuto.libraryDir + "/music/assorted";
  };
  useZLUDA = false;
  useRocm = useZLUDA;
  rocmPackages =
    if useZLUDA
    then pkgs.rocmPackages_5
    else pkgs.rocmPackages;
  zluda = let
    rustChannel = gensokyo-zone.inputs.systemd2mqtt.inputs.rust.legacyPackages.x86_64-linux.releases."1.79.0";
  in
    pkgs.zluda.override {
      inherit rocmPackages;
      inherit (rustChannel) rustPlatform;
      inherit (rustChannel.buildChannel) rustc;
    };
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.reisen-ct
    nixos.sops
    nixos.tailscale
    nixos.nginx
    nixos.access.plex
    nixos.access.deluge
    nixos.cloudflared
    ./cloudflared.nix

    # media
    nixos.kyuuto
    nixos.plex
    nixos.tautulli
    nixos.ombi
    nixos.deluge
    nixos.mediatomb
    nixos.invidious

    # accelerated
    #nixos.wyoming.whisper
    #nixos.wyoming.piper
    #nixos.wyoming.openwakeword

    # yarr harr fiddle dee dee >w<
    nixos.radarr
    nixos.sonarr
    nixos.bazarr
    nixos.lidarr
    nixos.readarr
    nixos.prowlarr
  ];

  services.nginx = {
    proxied.enable = true;
    vouch.enable = true;
    virtualHosts = {
      deluge.proxied.enable = "cloudflared";
    };
  };

  services.mediatomb = {
    serverName = "tewi";
    mediaDirectories = let
      libraryDir = {
        path = kyuuto.libraryDir;
        mountPoint = kyuuto.libraryDir;
        subdirectories =
          mapAttrsToList (
            _: {hostPath, ...}:
              removePrefix "${kyuuto.libraryDir}/" hostPath
          )
          plexLibrary
          ++ [
            "music/collections"
            "music/raw"
          ];
      };
    in [libraryDir];
  };

  nixpkgs.config = mkIf useZLUDA {
    cudaSupport = true;
  };
  hardware.graphics = {
    enable = true;
    extraPackages = with pkgs;
      mkMerge [
        [mesa.drivers]
        (mkIf useZLUDA [zluda])
        (mkIf useRocm [rocmPackages.clr.icd rocmPackages.clr])
      ];
  };
  environment.systemPackages = with pkgs; [
    radeontop
    (mkIf useRocm rocmPackages.rocminfo)
  ];

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
          device = kyuuto.downloadsDir + "/deluge/download";
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

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "21.05";
}
