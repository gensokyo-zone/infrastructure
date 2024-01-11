{
  config,
  lib,
  ...
}: let
  inherit (lib) mkDefault;
  cfg = config.services.deluge;
in {
  sops.secrets.deluge-auth = {
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
}
