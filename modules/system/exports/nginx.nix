{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.nginx = {
    config,
    systemConfig,
    ...
  }: let
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
    displayName = mkAlmostOptionDefault "NGINX/${systemConfig.name}";
    nixos = {
      serviceAttr = "nginx";
      assertions = mkIf config.enable (map mkAssertion [
        assertPorts
        assertProxied
        assertProxiedPort
      ]);
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = {
      http = {
        port = mkAlmostOptionDefault 80;
        protocol = "http";
        status = {
          enable = mkAlmostOptionDefault true;
          gatus.http.statusCondition = mkAlmostOptionDefault "[STATUS] == any(200, 404)";
        };
      };
      https = {
        enable = mkAlmostOptionDefault false;
        port = mkAlmostOptionDefault 443;
        protocol = "https";
        status = {
          enable = mkAlmostOptionDefault config.ports.http.status.enable;
          gatus.http.statusCondition = mkAlmostOptionDefault config.ports.http.status.gatus.http.statusCondition;
        };
      };
      proxied = {
        enable = mkAlmostOptionDefault false;
        port = mkAlmostOptionDefault 9080;
        protocol = "http";
        listen = "lan";
      };
    };
  };
}
