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
        # allow the z_offset to be saved by moonraker
        bltouch.z_offset = mkDefault 1.85;
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
