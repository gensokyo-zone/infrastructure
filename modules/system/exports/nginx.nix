{lib, gensokyo-zone, ...}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.nginx = { config, ... }: let
    mkAssertion = f: nixosConfig: let
      cfg = nixosConfig.services.nginx;
    in f nixosConfig cfg;
    assertPorts = nixosConfig: cfg: {
      assertion = config.ports.http.port == cfg.defaultHTTPListenPort && config.ports.https.port == cfg.defaultSSLListenPort;
      message = "ports mismatch";
    };
  in {
    nixos = {
      serviceAttr = "nginx";
      assertions = mkIf config.enable [
        (mkAssertion assertPorts)
      ];
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
    };
  };
}
