{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.nginx = {config, ...}: let
    mkAssertion = f: nixosConfig: let
      cfg = nixosConfig.services.nginx;
    in
      f nixosConfig cfg;
    assertPorts = nixosConfig: cfg: {
      assertion = config.ports.http.port == cfg.defaultHTTPListenPort && config.ports.https.port == cfg.defaultSSLListenPort;
      message = "ports mismatch";
    };
    assertProxied = nixosConfig: cfg: {
      assertion = config.ports.proxied.enable == cfg.proxied.enable;
      message = "proxied mismatch";
    };
    assertProxiedPort = nixosConfig: cfg: {
      assertion = !config.ports.proxied.enable || config.ports.proxied.port == cfg.proxied.listenPort;
      message = "proxied.port mismatch";
    };
  in {
    nixos = {
      serviceAttr = "nginx";
      assertions = mkIf config.enable (map mkAssertion [
        assertPorts
        assertProxied
        assertProxiedPort
      ]);
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      http = {
        port = 80;
        protocol = "http";
      };
      https = {
        enable = false;
        port = 443;
        protocol = "https";
      };
      proxied = {
        enable = false;
        port = 9080;
        protocol = "http";
        listen = "lan";
      };
    };
  };
}
