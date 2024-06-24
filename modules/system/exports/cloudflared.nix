{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.cloudflared = {config, systemConfig, ...}: let
    assertMetrics = nixosConfig: let
      cfg = nixosConfig.services.cloudflared;
      metricsPort =
        if config.ports.metrics.enable
        then config.ports.metrics.port
        else null;
    in {
      assertion = metricsPort == cfg.metricsPort;
      message = "metricsPort mismatch";
    };
  in {
    displayName = mkAlmostOptionDefault "Cloudflare Tunnel/${systemConfig.name}";
    nixos = {
      serviceAttr = "cloudflared";
      assertions = mkIf config.enable [
        assertMetrics
      ];
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = {
      metrics = {
        port = mkAlmostOptionDefault 3011;
        protocol = "http";
        status = {
          enable = true;
          gatus.http = {
            statusCondition = mkAlmostOptionDefault "[STATUS] == 404";
          };
        };
        prometheus.exporter.enable = mkAlmostOptionDefault true;
      };
    };
  };
}
