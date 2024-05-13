{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.freepbx = {
    id = mkAlmostOptionDefault "pbx";
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      http = {
        port = 80;
        protocol = "http";
      };
      https = {
        port = 443;
        protocol = "https";
      };
      ucp = {
        port = 8001;
        protocol = "http";
      };
      ucp-ssl = {
        port = 8003;
        protocol = "https";
      };
      asterisk = {
        port = 8088;
        protocol = "http";
      };
      asterisk-ssl = {
        port = 8089;
        protocol = "https";
      };
    };
  };
}
