{
  access,
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone) systems;
  inherit (gensokyo-zone.lib) mkAddress6 mapOptionDefaults;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) filter concatMap;
  nodeExporterSystems =
    filter (
      system:
        system.exports.prometheus.exporter.enable
        && system.exports.prometheus.exporter.services != []
    )
    (attrValues systems);
  mkPortTarget = {
    system,
    service,
    portName,
  }: let
    port = service.ports.${portName};
    # TODO: this properly
    getAddressFor =
      if port.status.gatus.client.network or "ip" == "ip4"
      then "getAddress4For"
      else "getAddressFor";
  in "${mkAddress6 (access.${getAddressFor} system.name "lan")}:${toString port.port}";
  mkServiceConfig = system: serviceName: let
    inherit (service.prometheus) exporter;
    service = system.exports.services.${serviceName};
    targets = map (portName:
      mkPortTarget {
        inherit system service portName;
      })
    exporter.ports;
  in {
    job_name = "${system.name}-${service.id}";
    static_configs = [
      {
        inherit targets;
        labels = mkMerge [
          (mapOptionDefaults exporter.labels)
          (mkIf (exporter.metricsPath != "/metrics") {
            __metrics_path__ = mkOptionDefault exporter.metricsPath;
          })
        ];
      }
    ];
    scheme = mkIf exporter.ssl.enable (mkDefault "https");
    tls_config = mkIf (exporter.ssl.enable && exporter.ssl.insecure) {
      insecure_skip_verify = mkDefault true;
    };
  };
  mapSystem = system: map (mkServiceConfig system) system.exports.prometheus.exporter.services;
in {
  services.prometheus = {
    port = mkDefault 9090;
    scrapeConfigs = concatMap mapSystem nodeExporterSystems;
  };
}
