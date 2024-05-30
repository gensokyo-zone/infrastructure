{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (config.services) grafana loki prometheus;
in {
  services = {
    grafana.enable = true;
    loki.enable = true;
    prometheus.enable = true;
  };
  networking.firewall.interfaces.lan.allowedTCPPorts = mkMerge [
    (mkIf grafana.enable [grafana.settings.server.http_port])
    (mkIf loki.enable [
      loki.configuration.server.http_listen_port
      (mkIf (loki.configuration.server.grpc_listen_port != 0) loki.configuration.server.grpc_listen_port)
    ])
    (mkIf prometheus.enable [prometheus.port])
  ];
}
