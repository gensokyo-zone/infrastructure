{config, lib, gensokyo-zone, ...}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (gensokyo-zone.lib) mkAlmostForce;
in {
  time.timeZone = mkDefault "America/Vancouver";

  services.ntp = mkIf config.boot.isContainer {
    enable = mkAlmostForce false;
  };
}
