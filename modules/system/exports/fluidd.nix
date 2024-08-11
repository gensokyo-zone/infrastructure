{
  config,
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  systemConfig = config;
in {
  config.exports.services.fluidd = {config, ...}: {
    displayName = mkAlmostOptionDefault "Fluidd";
    id = mkAlmostOptionDefault "print";
    nixos = {
      serviceAttr = "fluidd";
      assertions = let
        mkAssertion = f: nixosConfig: let
          cfg = nixosConfig.services.fluidd;
        in
          f nixosConfig cfg;
      in
        mkIf config.enable [
          (mkAssertion (nixosConfig: cfg: {
            assertion = config.ports.default.port == nixosConfig.services.nginx.proxied.listenPort;
            message = "port mismatch";
          }))
        ];
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = {
      default = {
        port = mkAlmostOptionDefault systemConfig.exports.services.nginx.ports.proxied.port;
        protocol = "http";
        status = {
          enable = mkAlmostOptionDefault true;
          gatus.settings.headers.Host = mkAlmostOptionDefault "fluidd_internal";
        };
        prometheus.exporter.enable = mkAlmostOptionDefault true;
      };
    };
  };
}
