{lib, ...}: let
  inherit (lib.modules) mkDefault;
in {
  time.timeZone = mkDefault "America/Vancouver";
}
