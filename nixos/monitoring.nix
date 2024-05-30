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
    (mkIf grafana.enable [ grafana.port ])
    (mkIf loki.enable [ loki.settings.httpListenPort loki.settings.grpcListenPort ])
    (mkIf prometheus.enable [ prometheus.port ])
  ];
}
