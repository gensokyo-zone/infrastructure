{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.freeipa = {
    id = mkAlmostOptionDefault "ipa";
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      default = {
        port = 443;
        protocol = "https";
      };
      redirect = {
        port = 80;
        protocol = "http";
      };
    };
  };
}
