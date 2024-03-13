{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkAfter mkDefault;
  inherit (lib.strings) hasPrefix removePrefix;
  inherit (config.services) mediatomb;
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
      enable = mkDefault true;
    };
    config = {
      max_upload_speed = 10.0;
      #share_ratio_limit = 2.0;
      max_connections_global = 1024;
      max_connections_per_second = 50;
      max_active_limit = 100;
      max_active_downloading = 75;
      max_upload_slots_global = 25;
      max_active_seeding = 8;
      allow_remote = true;
      daemon_port = 58846;
      listen_ports = [6881 6889];
      random_port = false;
    };
    authFile = config.sops.secrets.deluge-auth.path;
  };

  services.mediatomb.mediaDirectories = let
    inherit (cfg) downloadDir completedDir;
    parent = builtins.dirOf downloadDir;
    hasCompletedSubdir = completedDir != null && hasPrefix parent completedDir;
    completedSubdir = removePrefix parent completedDir;
    download =
      if hasCompletedSubdir
      then {
        path = parent;
        subdirectories = [
          (builtins.baseNameOf downloadDir)
          completedSubdir
        ];
      }
      else {
        path = downloadDir;
      };
    completed = {
      path = cfg.config.move_completed_path;
    };
  in
    mkIf cfg.enable (mkAfter [
      download
      (mkIf (completedDir != null && !hasCompletedSubdir) completed)
    ]);
  users.users = mkIf cfg.enable (mkMerge [
    {
      deluge.extraGroups = ["kyuuto"];
    }
    (mkIf mediatomb.enable {
      ${mediatomb.user}.extraGroups = [cfg.group];
    })
  ]);
}
