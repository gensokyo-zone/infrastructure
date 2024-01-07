{ config, utils, lib, ... }: with lib; let
  cfg = config.services.mediatomb;
  shadowDir = "/mnt/shadow";
  inherit (config.services) deluge;
in {
  services.mediatomb = {
    enable = true;
    openFirewall = true;
    port = 4152;
    serverName = config.networking.hostName;
    uuid = "082fd344-bf69-5b72-a68f-a5a4d88e76b2";
    mediaDirectories = [
      {
        path = "${shadowDir}/media";
        recursive = true;
        hidden-files = false;
      }
      (mkIf deluge.enable {
        path = builtins.dirOf deluge.config.download_location;
        recursive = true;
        hidden-files = false;
      })
    ];
  };
  systemd.services.mediatomb = {
    confinement.enable = true;
    bindsTo = [
      "${utils.escapeSystemdPath shadowDir}.mount"
    ];
    unitConfig = {
      RequiresMountsFor = [
        shadowDir
      ];
    };
    serviceConfig = {
      RestartSec = 15;
      StateDirectory = cfg.package.pname;
      BindReadOnlyPaths = mkMerge [
        (map (path: "${shadowDir}/media/${path}") [
          "anime" "movies" "tv" "unsorted"
          "music" "music-to-import" "music-raw"
        ])
        (mkIf deluge.enable [ deluge.config.move_completed_path ])
      ];
    };
  };
}
