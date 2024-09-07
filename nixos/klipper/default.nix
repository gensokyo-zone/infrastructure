{
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
      quiet = mkDefault true;
      octoprintIntegration = mkIf octoprint.enable (mkDefault true);
      configFiles = [
        ./printer.cfg
        ./ender3v3se.cfg
        ./macros.cfg
      ];
    };
  };
  systemd.services.klipper = mkIf cfg.enable {
    restartIfChanged = false;
  };
}
