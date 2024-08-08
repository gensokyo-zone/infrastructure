{ config, gensokyo-zone, ... }: let
  inherit (config.services) motion;
  inherit (gensokyo-zone.lib) domain;
 in {
  sops.secrets = {
    moonraker_cfg = {
      sopsFile = ./secrets/moonraker.yaml;
      path = "/var/lib/moonraker/config/secrets.conf";
      owner = "octoprint";
    };
   };
  services = {
    moonraker = {
      enable = true;
      address = "0.0.0.0";
      user = "octoprint";
      port = 7125; # it's the default but i'm specifying it anyway
      settings = {
        "include secrets.conf" = { };
        octoprint_compat = { };
        history = { };
        "webcam printer" = {
          location = "printer";
          enabled = true;
          service = "mjpegstreamer";
          icon = "mdiPrinter3d";
          target_fps = 5;
          target_fps_idle = 1;
          stream_url = let
            inherit (motion.cameras) printercam;
            inherit (printercam.settings) camera_id;
          in "https://kitchen.local.${domain}/${toString camera_id}/stream";
          snapshot_url = let
            inherit (motion.cameras) printercam;
        inherit (printercam.settings) camera_id;
          in "https://kitchen.local.${domain}/${toString camera_id}/current";
          aspect_ratio = "16:9";
        };
        authorization = {
          force_logins = true;
          cors_domains = [
            "*.local"
            "*.lan"
            "*.gensokyo.zone"
          ];
          trusted_clients = [
            "10.0.0.0/8"
            "127.0.0.0/8"
            "::1/128"
          ];
        };
      };
    };
  };
}
