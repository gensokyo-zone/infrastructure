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
      package = pkgs.klipper-ender3v3se;
      quiet = mkDefault true;
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
  systemd.services.klipper = mkIf cfg.enable {
    restartIfChanged = false;
  };
  services.udev.extraRules = mkIf cfg.enable ''
    SUBSYSTEM=="tty", ATTRS{idVendor}=="1a86", ATTRS{idProduct}=="7523", SYMLINK+="ttyEnder3v3se"
  '';
}
