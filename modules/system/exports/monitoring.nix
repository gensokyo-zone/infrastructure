{lib, gensokyo-zone, ...}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
   config.exports.services = {
          prometheus = { config, ... }: {
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
          prometheus-exporters-node = { config, ... }: {
            id = mkAlmostOptionDefault "prometheus-exporters-node";
            nixos = {
              serviceAttrPath = [ "services" "prometheus" "exporters" "node" ];
              assertions = mkIf config.enable [
                (nixosConfig: {
                  assertion = config.ports.default.port == nixosConfig.services.prometheus.exporters.node.port;
                  message = "port mismatch";
                })
              ];
            };
            ports.default = mapAlmostOptionDefaults {
              port = 9091;
              protocol = "http";
            };
          };
          grafana = { config, ... }: {
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
          loki = { config, ... }: {
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
          promtail = { config, ... }: {
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
      };
     }
