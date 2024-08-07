{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.fluidd = {config, ...}: {
    displayName = mkAlmostOptionDefault "Fluidd";
    id = mkAlmostOptionDefault "print";
    nixos = {
      serviceAttr = "fluidd";
      assertions = let
        mkAssertion = f: nixosConfig: let
          cfg = nixosConfig.services.nginx;
        in
          f nixosConfig cfg;
      in
        mkIf config.enable [
          (mkAssertion (nixosConfig: cfg: {
            assertion = config.ports.default.port == 80;
            message = "port mismatch";
          }))
        ];
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = {
      default = {
        port = mkAlmostOptionDefault 80;
        protocol = "http";
        status = {
          enable = mkAlmostOptionDefault true;
          gatus.client.network = mkAlmostOptionDefault "ip4";
        };
        prometheus.exporter.enable = mkAlmostOptionDefault true;
      };
    };
  };
}
