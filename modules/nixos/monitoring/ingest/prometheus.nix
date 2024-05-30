{
  access,
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone) systems;
  inherit (gensokyo-zone.lib) mkAddress6;
  inherit (lib.modules) mkDefault;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) filter concatMap;
  nodeExporterSystems =
    filter (
      system:
        system.config.access.online.enable
        && system.config.exports.prometheus.exporter.services != []
    )
    (attrValues systems);
  mkPortTarget = {
    system,
    service,
    portName,
  }: let
    port = service.ports.${portName};
  in "${mkAddress6 (access.getAddressFor system.config.name "lan")}:${toString port.port}";
  mkServiceConfig = system: serviceName: let
    service = system.config.exports.services.${serviceName};
    targets = map (portName:
      mkPortTarget {
        inherit system service portName;
      })
    service.prometheus.exporter.ports;
  in {
    job_name = "${system.config.name}-${service.id}";
    static_configs = [
      {
        inherit targets;
        labels = mkDefault service.prometheus.exporter.labels;
      }
    ];
  };
  mapSystem = system: map (mkServiceConfig system) system.config.exports.prometheus.exporter.services;
in {
  services.prometheus = {
    port = mkDefault 9090;
    scrapeConfigs = concatMap mapSystem nodeExporterSystems;
  };
}
