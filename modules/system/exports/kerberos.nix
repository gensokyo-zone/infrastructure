{lib, gensokyo-zone, ...}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.kerberos = { config, ... }: {
    id = "krb5";
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      default = {
        port = 88;
        transport = "tcp";
      };
      udp = {
        port = config.ports.default.port;
        transport = "udp";
      };
      kadmin = {
        port = 749;
        transport = "tcp";
      };
      kpasswd = {
        port = 464;
        transport = "tcp";
      };
      kpasswd-udp = {
        port = config.ports.kpasswd.port;
        transport = "udp";
      };
      ticket4 = {
        enable = false;
        port = 4444;
        transport = "udp";
      };
    };
  };
}
