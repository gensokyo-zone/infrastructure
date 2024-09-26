{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) octoprint;
  cfg = config.services.klipper;
in {
  services = {
    klipper = {
      enable = mkDefault true;
      package = mkDefault pkgs.klipper-ender3v3se;
      quiet = mkDefault true;
      logFile = mkDefault "/var/log/klipper/klippy.log";
      logRotate = mkDefault true;
      octoprintIntegration = mkIf octoprint.enable (mkDefault true);
      configFiles = [
        ./printer.cfg
        ./ender3v3se.cfg
        ./macros.cfg
      ];
      settings = {
        # allow settings to be saved by moonraker
        bltouch.z_offset = mkDefault 1.85;
        extruder = {
          control = "pid";
          #stock defaults provided by someone
          #pid_Kp = 27.142000;
          #pid_Ki = 1.371000;
          #pid_Kd = 134.351000;
          #recent PID_CALIBRATE results
          pid_Kp = 30.573;
          pid_Ki = 1.742;
          pid_Kd = 134.141;
        };
        heater_bed = {
          control = "pid";
          #stock defaults provided by someone
          #pid_Kp = 66.371000;
          #pid_Ki = 0.846000;
          #pid_Kd = 1301.702000;
          #recent PID_CALIBRATE results
          pid_Kp = 64.742;
          pid_Ki = 0.684;
          pid_Kd = 1531.969;
        };
      };
    };
  };
  systemd = mkIf cfg.enable {
    services.klipper = {
      restartIfChanged = false;
      serviceConfig = {
        Nice = mkDefault (-5);
      };
    };
    tmpfiles.rules = mkIf (cfg.logFile != null) [
      "d ${dirOf cfg.logFile} 0755 ${cfg.user} ${cfg.group} 8w -"
    ];
  };
  services.udev.extraRules = mkIf cfg.enable ''
    SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", SYMLINK+="ttyEnder3v3se"
  '';
}
