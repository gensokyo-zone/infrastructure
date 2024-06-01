{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.keycloak = {config, ...}: {
    displayName = mkAlmostOptionDefault "Keycloak";
    id = mkAlmostOptionDefault "sso";
    nixos = {
      serviceAttr = "keycloak";
      assertions = let
        mkAssertion = f: nixosConfig: let
          cfg = nixosConfig.services.keycloak;
        in
          f nixosConfig cfg;
      in
        mkIf config.enable [
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
    ports = {
      http = {
        enable = mkAlmostOptionDefault (!config.ports.https.enable);
        port = mkAlmostOptionDefault 8080;
        protocol = "http";
        status.enable = mkAlmostOptionDefault true;
      };
      https = {
        port = mkAlmostOptionDefault 8443;
        protocol = "https";
        status.enable = mkAlmostOptionDefault config.ports.http.status.enable;
      };
    };
  };
}
