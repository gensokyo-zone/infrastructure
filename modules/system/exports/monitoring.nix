let
  portModule = {lib, ...}: let
    inherit (lib.options) mkEnableOption;
  in {
    options.prometheus = with lib.types; {
      exporter.enable = mkEnableOption "prometheus metrics endpoint";
    };
  };
  serviceModule = {
    config,
    lib,
    ...
  }: let
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkOptionDefault;
    inherit (lib.attrsets) attrNames filterAttrs;
    exporterPorts = filterAttrs (_: port: port.enable && port.prometheus.exporter.enable) config.ports;
  in {
    options = with lib.types; {
      prometheus = {
        exporter = {
          ports = mkOption {
            type = listOf str;
          };
          labels = mkOption {
            type = attrsOf str;
            default = {};
          };
        };
      };
      ports = mkOption {
        type = attrsOf (submoduleWith {
          modules = [portModule];
        });
      };
    };
    config.prometheus = {
      exporter.ports = mkOptionDefault (attrNames exporterPorts);
    };
  };
in
  {
    config,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mapListToAttrs mapAlmostOptionDefaults mkAlmostOptionDefault;
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkIf mkOptionDefault;
    inherit (lib.attrsets) attrNames filterAttrs nameValuePair;
    mkExporter = {
      name,
      port,
    }:
      nameValuePair "prometheus-exporters-${name}" ({config, ...}: {
        nixos = {
          serviceAttrPath = ["services" "prometheus" "exporters" name];
          assertions = mkIf config.enable [
            (nixosConfig: {
              assertion = config.ports.default.port == nixosConfig.services.prometheus.exporters.${name}.port;
              message = "port mismatch";
            })
          ];
        };
        ports.default =
          mapAlmostOptionDefaults {
            inherit port;
            protocol = "http";
          }
          // {
            prometheus.exporter.enable = true;
          };
      });
    exporters = mapListToAttrs mkExporter [
      {
        name = "node";
        port = 9091;
      }
    ];
  in {
    options.exports = with lib.types; {
      prometheus = {
        exporter.services = mkOption {
          type = listOf str;
        };
      };
      services = mkOption {
        type = attrsOf (submoduleWith {
          modules = [serviceModule];
        });
      };
    };
    config.exports.prometheus = let
      exporterServices = filterAttrs (_: service: service.enable && service.prometheus.exporter.ports != []) config.exports.services;
    in {
      exporter.services = mkOptionDefault (attrNames exporterServices);
    };
    config.exports.services =
      {
        prometheus = {config, ...}: {
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
          id = mkAlmostOptionDefault "mon";
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
          id = mkAlmostOptionDefault "logs";
          nixos = {
            serviceAttr = "loki";
            assertions = mkIf config.enable [
              (nixosConfig: let
                inherit (nixosConfig.services.loki.configuration.server) http_listen_port;
              in {
                assertion = config.ports.default.port == http_listen_port;
                message = "port mismatch";
              })
              (nixosConfig: let
                inherit (nixosConfig.services.loki.configuration.server) grpc_listen_port;
              in {
                assertion = !config.ports.grpc.enable || config.ports.grpc.port == grpc_listen_port;
                message = "gRPC port mismatch";
              })
              (nixosConfig: let
                inherit (nixosConfig.services.loki.configuration.server) grpc_listen_port;
              in {
                assertion =
                  if config.ports.grpc.enable
                  then grpc_listen_port != 0
                  else grpc_listen_port == 0;
                message = "gRPC enable mismatch";
              })
            ];
          };
          ports = {
            default = mapAlmostOptionDefaults {
              port = 9093;
              protocol = "http";
            };
            grpc = mapAlmostOptionDefaults {
              enable = false;
              port = 9095;
              protocol = "http";
            };
            #grpclb.port = 9096;
          };
        };
        promtail = {config, ...}: {
          id = mkAlmostOptionDefault "promtail";
          nixos = {
            serviceAttr = "promtail";
            assertions = mkIf config.enable [
              (nixosConfig: {
                assertion = config.ports.default.port == nixosConfig.services.promtail.configuration.server.http_listen_port;
                message = "port mismatch";
              })
            ];
          };
          ports.default =
            mapAlmostOptionDefaults {
              port = 9094;
              protocol = "http";
            }
            // {
              prometheus.exporter.enable = true;
            };
          #ports.grpc = ...
        };
      }
      // exporters;
  }
