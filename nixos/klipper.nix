{ config, gensokyo-zone, lib, ... }: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) moonraker octoprint;
  cfg = config.services.klipper;
in {
  services = {
    klipper = {
      enable = mkDefault true;
      octoprintIntegration = mkIf octoprint.enable (mkDefault true);
      user = mkIf moonraker.enable (mkAlmostOptionDefault "moonraker");
      group = mkIf moonraker.enable (mkAlmostOptionDefault "moonraker");
      mutableConfig = true;
      mutableConfigFolder = mkIf moonraker.enable (mkDefault "${moonraker.stateDir}/config");
      settings = {};
    };
  };
}
