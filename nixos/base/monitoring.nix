{lib, systemConfig ? {}, ...}: let
  inherit (lib.modules) mkDefault;
  # TODO: pick new log source
  logServiceAttr = if false then "promtail" else null;
  # TODO: prefer to set this via systemConfig.modules instead
  monitoringExport = systemConfig.exports.prometheus.exporter.enable or true;
  monitoringPush = systemConfig.exports.prometheus.push.enable or true;
in {
  services = {
    prometheus.exporters.node.enable = mkDefault monitoringExport;
    ${logServiceAttr}.enable = mkDefault monitoringPush;
  };
}
