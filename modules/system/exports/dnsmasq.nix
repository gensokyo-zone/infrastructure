{lib, gensokyo-zone, ...}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.dnsmasq = { config, ... }: {
    id = mkAlmostOptionDefault "dns";
    nixos = {
      serviceAttr = "dnsmasq";
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      default = {
        port = 53;
        transport = "udp";
      };
      tcp = {
        port = config.ports.default.port;
        transport = "tcp";
      };
    };
  };
}
