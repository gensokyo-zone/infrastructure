{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
in {
  config.exports.services.unifi = {config, ...}: {
    nixos.serviceAttr = "unifi";
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = {
      management = {
        # remote login
        port = mkAlmostOptionDefault 8443;
        protocol = "https";
        listen = "int";
        status.enable = mkAlmostOptionDefault true;
      };
      uap = {
        # UAP to inform controller
        port = mkAlmostOptionDefault 8080;
        transport = "tcp";
      };
      portal = {
        # HTTP portal redirect, if guest portal is enabled
        port = mkAlmostOptionDefault 8880;
        protocol = "http";
      };
      portal-secure = {
        # HTTPS portal redirect
        port = mkAlmostOptionDefault 8843;
        protocol = "https";
      };
      speedtest = {
        # UniFi mobile speed test
        port = mkAlmostOptionDefault 6789;
        transport = "tcp";
      };
      stun = {
        port = mkAlmostOptionDefault 3478;
        transport = "udp";
        listen = "wan";
      };
      discovery = {
        # device discovery
        port = mkAlmostOptionDefault 10001;
        transport = "udp";
      };
    };
  };
}
