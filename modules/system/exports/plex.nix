{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
in {
  config.exports.services.plex = {
    displayName = mkAlmostOptionDefault "Plex";
    nixos.serviceAttr = "plex";
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = {
      default = {
        port = mkAlmostOptionDefault 32400;
        protocol = "http";
        status = {
          enable = mkAlmostOptionDefault true;
          gatus.http.statusCondition = mkAlmostOptionDefault "[STATUS] == 401";
        };
      };
      roku = {
        port = mkAlmostOptionDefault 8324;
        transport = "tcp";
      };
      dlna-tcp = {
        port = mkAlmostOptionDefault 32469;
        transport = "tcp";
      };
      dlna-udp = {
        port = mkAlmostOptionDefault 1900;
        transport = "udp";
      };
      gdm0 = {
        port = mkAlmostOptionDefault 32410;
        transport = "udp";
      };
      gdm1 = {
        port = mkAlmostOptionDefault 32412;
        transport = "udp";
      };
      gdm2 = {
        port = mkAlmostOptionDefault 32413;
        transport = "udp";
      };
      gdm3 = {
        port = mkAlmostOptionDefault 32414;
        transport = "udp";
      };
    };
  };
}
