{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.unifi = {config, ...}: {
    nixos.serviceAttr = "unifi";
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      management = {
        # remote login
        port = 8443;
        protocol = "https";
        listen = "int";
      };
      uap = {
        # UAP to inform controller
        port = 8080;
        transport = "tcp";
      };
      portal = {
        # HTTP portal redirect, if guest portal is enabled
        port = 8880;
        protocol = "http";
      };
      portal-secure = {
        # HTTPS portal redirect
        port = 8843;
        protocol = "https";
      };
      speedtest = {
        # UniFi mobile speed test
        port = 6789;
        transport = "tcp";
      };
      stun = {
        port = 3478;
        transport = "udp";
        listen = "wan";
      };
      discovery = {
        # device discovery
        port = 10001;
        transport = "udp";
      };
    };
  };
}
