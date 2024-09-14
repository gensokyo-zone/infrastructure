{
  pkgs,
  config,
  access,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault domain;
  inherit (lib.modules) mkIf mkMerge mkBefore mkDefault;
  inherit (lib.strings) concatStringsSep;
  inherit (config.services) klipper;
  cfg = config.services.moonraker;
  controlServices = [
    # defaults: https://github.com/Arksine/moonraker/blob/71f9e677b81afcc6b99dd5002f595025c38edc7b/moonraker/assets/default_allowed_services
    "klipper"
  ];
  controlServiceUnits = map (name: "${name}.service") controlServices;
  controlServicesFile = pkgs.writeText "moonraker.asvc" (concatStringsSep "\n" controlServices);
  allowSystemControl = true;
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
        octoprint_compat = {
          stream_url = "/webcam/stream";
          webcam_enabled = true;
        };
        history = {};
        "webcam printer" = {
          location = "printer";
          enabled = true;
          service = "mjpegstreamer";
          icon = "mdiPrinter3d";
          target_fps = 5;
          target_fps_idle = 1;
          stream_url = "/webcam/stream";
          snapshot_url = "/webcam/current";
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
          provider = mkMerge [
            # tell moonraker when machine control should be disabled
            (mkIf (!allowSystemControl && !cfg.allowSystemControl) "none")
            # the default systemd_dbus provider is too aggressive about checking for permission first...
            (mkIf (allowSystemControl && !cfg.allowSystemControl) (mkAlmostOptionDefault "systemd_cli"))
          ];
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
      preStart = mkIf allowSystemControl ''
        ln -sf ${controlServicesFile} ${cfg.stateDir}/moonraker.asvc
      '';
    };
  };
  security.polkit = mkIf (cfg.enable && (allowSystemControl || cfg.allowSystemControl)) {
    enable = mkDefault true;
    extraConfig = mkIf (allowSystemControl && !cfg.allowSystemControl) ''
      // moonraker machine control
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.systemd1.manage-units" && subject.user == "${cfg.user}") {
          if (${builtins.toJSON controlServiceUnits}.indexOf(action.lookup("unit")) > -1) {
            return polkit.Result.YES;
          }
        }
      });
    '';
  };

  networking.firewall = mkIf cfg.enable {
    interfaces.lan.allowedTCPPorts = [
      cfg.port
    ];
  };
}
