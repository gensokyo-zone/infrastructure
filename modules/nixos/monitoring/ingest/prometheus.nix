{
  access,
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone) systems;
  inherit (lib.attrsets) filterAttrs mapAttrsToList;
  nodeExporterSystems =
    filterAttrs (
      _: system:
        system.config.access.online.enable &&
        system.config.exports.services.prometheus-exporters-node.enable
    )
    systems;
in {
  services.prometheus = {
    port = 9090;
    scrapeConfigs =
      mapAttrsToList (_: system: {
        job_name = "${system.config.name}-node-exporter";
        static_configs = [ {
          targets = [
            "${access.getAddressFor system.config.name "local"}:${toString system.config.exports.services.prometheus-exporters-node.ports.default.port}"
          ];
        } ];
      })
      nodeExporterSystems;
  };
}
