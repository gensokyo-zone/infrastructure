{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
in {
  config.exports.services.freeipa = {
    displayName = mkAlmostOptionDefault "FreeIPA";
    id = mkAlmostOptionDefault "ipa";
    ports = {
      default = {
        port = mkAlmostOptionDefault 443;
        protocol = "https";
        status.enable = mkAlmostOptionDefault true;
      };
      redirect = {
        port = mkAlmostOptionDefault 80;
        protocol = "http";
      };
    };
  };
}
