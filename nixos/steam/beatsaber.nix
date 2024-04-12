{lib, ...}: let
  inherit (lib.modules) mkDefault;
in {
  services.steam.beatsaber = {
    enable = mkDefault true;
    defaultVersion = mkDefault "1.29.0";
    versions = {
      "1.29.0" = {};
      "1.34.2" = {};
    };
    users = {
      arc.preferredVersion = "1.29.0";
      kat.preferredVersion = "1.29.0";
      kaosubaloo.preferredVersion = "1.29.0";
    };
  };
}
