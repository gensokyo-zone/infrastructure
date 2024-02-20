{lib, gensokyo-zone, ...}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.samba = {
    id = mkAlmostOptionDefault "smb";
    nixos.serviceAttr = "samba";
    # TODO: expose over wan
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      port0 = {
        port = 137;
        transport = "udp";
      };
      port1 = {
        port = 138;
        transport = "udp";
      };
      port2 = {
        port = 139;
        transport = "tcp";
      };
      default = {
        port = 445;
        transport = "tcp";
      };
    };
  };
}
