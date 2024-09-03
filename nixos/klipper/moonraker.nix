{
  config,
  access,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkBefore mkDefault;
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault domain;
  inherit (config.services) klipper;
  cfg = config.services.moonraker;
in {
  sops.secrets = {
    moonraker_cfg = {
      sopsFile = mkDefault ../secrets/moonraker.yaml;
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
    klipper = mkIf cfg.enable {
      user = mkAlmostOptionDefault "moonraker";
      group = mkAlmostOptionDefault "moonraker";
      mutableConfig = true;
      mutableConfigFolder = mkDefault "${cfg.stateDir}/config";
      configFiles = mkBefore [./fluidd.cfg];
      settings = {
        print_stats = {};
        pause_resume = {};
        display_status = {};
        virtual_sdcard = {
          path = "${cfg.stateDir}/gcodes";
          on_error_gcode = mkAlmostOptionDefault "CANCEL_PRINT";
        };
      };
    };
  };
  systemd.services = mkIf cfg.enable {
    moonraker = {
      restartIfChanged = false;
    };
  };
  networking.firewall = mkIf cfg.enable {
    interfaces.lan.allowedTCPPorts = [
      cfg.port
    ];
  };
}
