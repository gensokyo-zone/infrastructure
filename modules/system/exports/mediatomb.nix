{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
in {
  config.exports.services.mediatomb = {config, ...}: {
    displayName = mkAlmostOptionDefault "Mediatomb";
    nixos = {
      serviceAttr = "mediatomb";
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = let
      #gatus.client.network = mkAlmostOptionDefault "ip4";
    in {
      default = {
        port = mkAlmostOptionDefault 49152;
        transport = "http";
        status = {
          #inherit gatus;
          #enable = mkAlmostOptionDefault true;
        };
      };
      upnp-tcp = {
        port = mkAlmostOptionDefault 1900;
        protocol = "tcp";
        #status = { inherit gatus; };
      };
      upnp-udp = {
        port = mkAlmostOptionDefault 1900;
        protocol = "udp";
      };
    };
  };
}
