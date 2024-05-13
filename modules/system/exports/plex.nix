{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.plex = {
    nixos.serviceAttr = "plex";
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      default = {
        port = 32400;
        protocol = "http";
      };
      roku = {
        port = 8324;
        transport = "tcp";
      };
      dlna-tcp = {
        port = 32469;
        transport = "tcp";
      };
      dlna-udp = {
        port = 1900;
        transport = "udp";
      };
      gdm0 = {
        port = 32410;
        transport = "udp";
      };
      gdm1 = {
        port = 32412;
        transport = "udp";
      };
      gdm2 = {
        port = 32413;
        transport = "udp";
      };
      gdm3 = {
        port = 32414;
        transport = "udp";
      };
    };
  };
}
