let
  portModule = {
    systemConfig,
    config,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mapOptionDefaults unmerged;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkMerge mkOptionDefault;
  in {
    options = with lib.types; {
      prometheus = {
        exporter.enable = mkEnableOption "prometheus metrics endpoint";
      };
      status = {
        enable = mkEnableOption "status checks";
        alert = {
          enable =
            mkEnableOption "health check alerts"
            // {
              default = systemConfig.exports.status.alert.enable;
            };
        };
        gatus = {
          enable =
            mkEnableOption "gatus"
            // {
              default = true;
            };
          client = {
            network = mkOption {
              type = enum ["ip" "ip4" "ip6"];
              default = "ip";
            };
          };
          http = {
            path = mkOption {
              type = str;
              default = "/";
            };
            statusCondition = mkOption {
              type = nullOr str;
            };
            websocket = {
              enable = mkEnableOption "ws://";
              status = mkOption {
                type = int;
                default = 200;
              };
            };
          };
          protocol = mkOption {
            type = str;
          };
          settings = mkOption {
            type = unmerged.types.attrs;
          };
        };
      };
    };
    config = {
      status.gatus = let
        cfg = config.status.gatus;
        useWebsocket = cfg.http.websocket.enable && cfg.http.websocket.status == 200;
        mockWebsocket = cfg.http.websocket.enable && cfg.http.websocket.status != 200;
        protocolWs =
          if config.ssl || config.protocol == "https"
          then "wss"
          else "ws";
        protocolHttp =
          if config.ssl || config.protocol == "https"
          then "https"
          else "http";
        defaultProtocol =
          if useWebsocket
          then mkOptionDefault protocolWs
          else if cfg.http.websocket.enable
          then mkOptionDefault protocolHttp
          else if config.protocol != null
          then mkOptionDefault config.protocol
          else if config.starttls
          then mkOptionDefault "starttls"
          else if config.ssl
          then mkOptionDefault "tls"
          else if config.transport != "unix"
          then mkOptionDefault config.transport
          else mkIf false (throw "unreachable");
      in {
        protocol = defaultProtocol;
        http.statusCondition = mkOptionDefault (
          if mockWebsocket
          then "[STATUS] == ${toString cfg.http.websocket.status}"
          else if cfg.protocol == "http" || cfg.protocol == "https"
          then "[STATUS] == 200"
          else null
        );
        settings = mkMerge [
          {
            conditions = mkMerge [
              (mkIf (config.ssl || config.starttls) (mkOptionDefault [
                "[CERTIFICATE_EXPIRATION] > 72h"
              ]))
            ];
          }
          (mkIf (cfg.http.statusCondition != null) {
            conditions = mkOptionDefault [
              cfg.http.statusCondition
            ];
          })
          (mkIf (cfg.protocol == "dns") {
            conditions = mkOptionDefault [
              "[DNS_RCODE] == NOERROR"
            ];
          })
          (mkIf mockWebsocket {
            headers = mapOptionDefaults {
              Connection = "Upgrade";
              Upgrade = "websocket";
              Sec-WebSocket-Version = "13";
              Sec-WebSocket-Key = "SGVsbG8sIHdvcmxkIQ==";
            };
          })
        ];
      };
    };
  };
  serviceModule = {
    systemConfig,
    config,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mapOptionDefaults;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkOptionDefault;
    inherit (lib.attrsets) attrNames attrValues filterAttrs;
    inherit (lib.lists) any;
    exporterPorts = filterAttrs (_: port: port.enable && port.prometheus.exporter.enable) config.ports;
    statusPorts = filterAttrs (_: port: port.enable && port.status.enable) config.ports;
  in {
    options = with lib.types; {
      prometheus = {
        exporter = {
          ports = mkOption {
            type = listOf str;
          };
          labels = mkOption {
            type = attrsOf str;
          };
          metricsPath = mkOption {
            type = str;
            default = "/metrics";
          };
          ssl = {
            enable =
              mkEnableOption "HTTPS"
              // {
                default = any (port: port.ssl) (attrValues exporterPorts);
              };
            insecure =
              mkEnableOption "self-signed SSL"
              // {
                default = true;
              };
          };
        };
      };
      status = {
        ports = mkOption {
          type = listOf str;
        };
      };
      ports = mkOption {
        type = attrsOf (submoduleWith {
          modules = [portModule];
        });
      };
    };
    config = {
      prometheus.exporter = {
        ports = mkOptionDefault (attrNames exporterPorts);
        labels = mapOptionDefaults {
          gensokyo_exports_service = config.name;
          gensokyo_exports_id = config.id;
          gensokyo_system = systemConfig.name;
          gensokyo_host = systemConfig.access.fqdn;
        };
      };
      status = {
        ports = mkOptionDefault (attrNames statusPorts);
      };
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
    inherit (lib.options) mkOption mkEnableOption;
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
            prometheus.exporter.enable = mkAlmostOptionDefault true;
          };
      });
    exporters = mapListToAttrs mkExporter [
      {
        name = "node";
        port = 9091;
      }
      {
        name = "unifi";
        port = 9130;
      }
    ];
  in {
    options.exports = with lib.types; {
      prometheus = {
        exporter = {
          enable =
            mkEnableOption "prometheus ingress"
            // {
              default = config.access.online.enable;
            };
          services = mkOption {
            type = listOf str;
          };
        };
      };
      status = {
        enable =
          mkEnableOption "status checks"
          // {
            default = config.access.online.enable;
          };
        alert = {
          enable =
            mkEnableOption "health check alerts"
            // {
              default = config.access.online.enable && config.access.online.available;
            };
        };
        services = mkOption {
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
    config.exports.status = let
      statusServices = filterAttrs (_: service: service.enable && service.status.ports != []) config.exports.services;
    in {
      services = mkOptionDefault (attrNames statusServices);
    };
    config.exports.services =
      {
        prometheus = {config, ...}: {
          displayName = mkAlmostOptionDefault "Prometheus";
          nixos = {
            serviceAttr = "prometheus";
            assertions = mkIf config.enable [
              (nixosConfig: {
                assertion = config.ports.default.port == nixosConfig.services.prometheus.port;
                message = "port mismatch";
              })
            ];
          };
          ports.default = {
            port = mkAlmostOptionDefault 9090;
            protocol = "http";
            status.enable = mkAlmostOptionDefault true;
          };
        };
        grafana = {config, ...}: {
          id = mkAlmostOptionDefault "mon";
          displayName = mkAlmostOptionDefault "Grafana";
          nixos = {
            serviceAttr = "grafana";
            assertions = mkIf config.enable [
              (nixosConfig: {
                assertion = config.ports.default.port == nixosConfig.services.grafana.settings.server.http_port;
                message = "port mismatch";
              })
            ];
          };
          ports.default = {
            port = mkAlmostOptionDefault 9092;
            protocol = "http";
            prometheus.exporter.enable = mkAlmostOptionDefault true;
            status.enable = mkAlmostOptionDefault true;
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
          nixos = {
            serviceAttr = "promtail";
            assertions = mkIf config.enable [
              (nixosConfig: {
                assertion = config.ports.default.port == nixosConfig.services.promtail.configuration.server.http_listen_port;
                message = "port mismatch";
              })
            ];
          };
          ports.default = {
            port = mkAlmostOptionDefault 9094;
            protocol = "http";
            prometheus.exporter.enable = mkAlmostOptionDefault true;
          };
          #ports.grpc = ...
        };
        gatus = {config, ...}: {
          id = mkAlmostOptionDefault "status";
          nixos = {
            serviceAttr = "gatus";
            assertions = mkIf config.enable [
              (nixosConfig: {
                assertion = config.ports.default.port == nixosConfig.services.gatus.settings.web.port;
                message = "port mismatch";
              })
            ];
          };
          ports.default = {
            port = mkAlmostOptionDefault 9095;
            protocol = "http";
            prometheus.exporter.enable = mkAlmostOptionDefault true;
          };
          #ports.grpc = ...
        };
      }
      // exporters;
  }
