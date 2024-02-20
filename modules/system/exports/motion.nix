{lib, gensokyo-zone, ...}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.motion = { config, ... }: {
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      default = {
        port = 8080;
        protocol = "http";
      };
      stream = {
        port = 8081;
        protocol = "http";
      };
    };
  };
}
