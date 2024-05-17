{ access, lib, gensokyo-zone, ... }: let
  inherit (gensokyo-zone) systems;
  inherit (lib.attrsets) filterAttrs mapAttrsToList attrNames;
  nodeExporterSystems = filterAttrs (_: system:
    system.config.exporters.prometheus-exporters-node.enable or false
  ) systems;
 in {
    services.prometheus = {
        #enable = true;
        port = 9090;
        scrapeConfigs = mapAttrsToList (system: systemConfig: {
                job_name = "${system.config.name}-node-exporter";
                static_configs = {
                     targets = [
                        "${access.getAddressFor system.config.name "local"}:${system.config.exporters.prometheus-exporters-node.port}"
                     ];
                };
           }) nodeExporterSystems;
    };
}