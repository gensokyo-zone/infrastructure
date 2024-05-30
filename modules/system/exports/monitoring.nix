{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapListToAttrs mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) nameValuePair;
  mkExporter = { name, port }: nameValuePair "prometheus-exporters-${name}" ({config, ...}: {
    nixos = {
      serviceAttrPath = ["services" "prometheus" "exporters" name];
      assertions = mkIf config.enable [
        (nixosConfig: {
          assertion = config.ports.default.port == nixosConfig.services.prometheus.exporters.${name}.port;
          message = "port mismatch";
        })
      ];
    };
    ports.default = mapAlmostOptionDefaults {
      inherit port;
      protocol = "http";
    };
  });
  exporters = mapListToAttrs mkExporter [
    { name = "node"; port = 9091; }
  ];
in {
  config.exports.services = {
    prometheus = {config, ...}: {
      id = mkAlmostOptionDefault "prometheus";
      nixos = {
        serviceAttr = "prometheus";
        assertions = mkIf config.enable [
          (nixosConfig: {
            assertion = config.ports.default.port == nixosConfig.services.prometheus.port;
            message = "port mismatch";
          })
        ];
      };
      ports.default = mapAlmostOptionDefaults {
        port = 9090;
        protocol = "http";
      };
    };
    grafana = {config, ...}: {
      id = mkAlmostOptionDefault "grafana";
      nixos = {
        serviceAttr = "grafana";
        assertions = mkIf config.enable [
          (nixosConfig: {
            assertion = config.ports.default.port == nixosConfig.services.grafana.settings.server.http_port;
            message = "port mismatch";
          })
        ];
      };
      ports.default = mapAlmostOptionDefaults {
        port = 9092;
        protocol = "http";
      };
    };
    loki = {config, ...}: {
      id = mkAlmostOptionDefault "loki";
      nixos = {
        serviceAttr = "loki";
        assertions = mkIf config.enable [
          (nixosConfig: {
            assertion = config.ports.default.port == nixosConfig.services.loki.settings.httpListenPort;
            message = "port mismatch";
          })
        ];
      };
      ports.default = mapAlmostOptionDefaults {
        port = 9093;
        protocol = "http";
      };
    };
    promtail = {config, ...}: {
      id = mkAlmostOptionDefault "promtail";
      nixos = {
        serviceAttr = "promtail";
        assertions = mkIf config.enable [
          (nixosConfig: {
            assertion = config.ports.default.port == nixosConfig.services.promtail.settings.httpListenPort;
            message = "port mismatch";
          })
        ];
      };
      ports.default = mapAlmostOptionDefaults {
        port = 9094;
        protocol = "http";
      };
    };
  } // exporters;
}
