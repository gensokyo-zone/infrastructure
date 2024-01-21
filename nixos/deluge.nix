{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkAfter mkDefault;
  inherit (lib.strings) hasPrefix removePrefix;
  cfg = config.services.deluge;
in {
  sops.secrets.deluge-auth = {
    sopsFile = mkDefault ./secrets/deluge.yaml;
    inherit (cfg) group;
    owner = cfg.user;
  };
  services.deluge = {
    enable = mkDefault true;
    declarative = mkDefault true;
    openFirewall = mkDefault true;
    web = {
      enable = true;
    };
    config = {
      max_upload_speed = 10.0;
      #share_ratio_limit = 2.0;
      max_connections_global = 1024;
      max_connections_per_second = 50;
      max_active_limit = 100;
      max_active_downloading = 75;
      max_upload_slots_global = 25;
      max_active_seeding = 1;
      allow_remote = true;
      daemon_port = 58846;
      listen_ports = [6881 6889];
      random_port = false;
    };
    authFile = config.sops.secrets.deluge-auth.path;
  };

  services.mediatomb.mediaDirectories = let
    downloadLocation = cfg.config.download_location or (cfg.dataDir + "/Downloads");
    parent = builtins.dirOf downloadLocation;
    hasCompletedSubdir = cfg.config.move_completed or false && hasPrefix parent cfg.config.move_completed_path;
    completedSubdir = removePrefix parent cfg.config.move_completed_path;
    downloadDir = if hasCompletedSubdir then {
      path = parent;
      subdirectories = [
        (builtins.baseNameOf downloadLocation)
        completedSubdir
      ];
    } else {
      path = downloadLocation;
    };
    completedDir = {
      path = cfg.config.move_completed_path;
    };
  in mkIf cfg.enable (mkAfter [
    downloadDir
    (mkIf (cfg.config.move_completed or false && !hasCompletedSubdir) completedDir)
  ]);
}
