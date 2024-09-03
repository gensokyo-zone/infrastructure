{
  config,
  access,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (gensokyo-zone.lib) domain;
  inherit (config.services) klipper;
  cfg = config.services.moonraker;
in {
  sops.secrets = {
    moonraker_cfg = {
      sopsFile = ./secrets/moonraker.yaml;
      path = "${cfg.stateDir}/config/secrets.conf";
      owner = cfg.user;
    };
  };
  services = {
    moonraker = {
      enable = mkDefault true;
      address = mkDefault "all";
      user = mkDefault klipper.user;
      group = mkDefault klipper.group;
      port = 7125; # it's the default but i'm specifying it anyway
      settings = {
        "include secrets.conf" = {};
        octoprint_compat = {};
        history = {};
        "webcam printer" = let
          inherit (config.services.motion.cameras) printercam;
          inherit (printercam.settings) camera_id;
        in {
          location = "printer";
          enabled = true;
          service = "mjpegstreamer";
          icon = "mdiPrinter3d";
          target_fps = 5;
          target_fps_idle = 1;
          stream_url = "https://kitchen.local.${domain}/${toString camera_id}/stream";
          snapshot_url = "https://kitchen.local.${domain}/${toString camera_id}/current";
          aspect_ratio = "16:9";
        };
        authorization = {
          force_logins = true;
          cors_domains = [
            "*.local"
            "*.lan"
            "*.${domain}"
          ];
          trusted_clients =
            access.cidrForNetwork.allLocal.all
            # XXX: only safe when protected behind vouch!
            ++ ["0.0.0.0/0" "::/0"];
        };
        machine = {
          # disable all machine control
          provider = "none";
        };
      };
    };
  };
  systemd.services.moonraker = mkIf cfg.enable {
    restartIfChanged = false;
  };
  networking.firewall = mkIf cfg.enable {
    interfaces.lan.allowedTCPPorts = [
      cfg.port
    ];
  };
}
