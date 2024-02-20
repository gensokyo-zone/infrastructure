{lib, gensokyo-zone, ...}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.keycloak = { config, ... }: {
    id = mkAlmostOptionDefault "sso";
    nixos = {
      serviceAttr = "keycloak";
      assertions = let
        mkAssertion = f: nixosConfig: let
          cfg = nixosConfig.services.keycloak;
        in f nixosConfig cfg;
      in mkIf config.enable [
        (mkAssertion (nixosConfig: cfg: {
          assertion = config.ports.${cfg.protocol}.port == cfg.port;
          message = "port mismatch";
        }))
        (mkAssertion (nixosConfig: cfg: {
          assertion = config.ports.${cfg.protocol}.enable;
          message = "port enable mismatch";
        }))
      ];
    };
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      http = {
        enable = !config.ports.https.enable;
        port = 8080;
        protocol = "http";
      };
      https = {
        port = 8443;
        protocol = "https";
      };
    };
  };
}
