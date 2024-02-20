{lib, gensokyo-zone, ...}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
in {
  config.exports.services.proxmox = { config, ... }: {
    id = mkAlmostOptionDefault "prox";
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports.default = mapAlmostOptionDefaults {
      port = 8006;
      protocol = "https";
    };
  };
}
