{
  pkgs,
  config,
  lib,
  access,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone) systems;
  inherit (lib.attrsets) filterAttrs mapAttrsToList;
  promtailSystems =
    filterAttrs (
      _: system:
        system.config.access.online.enable
        && system.config.exports.services.promtail.enable
    )
    systems;
  inherit (builtins) toJSON;
  inherit (lib.options) mkOption;
  inherit (lib.types) port;
  cfg = config.services.loki;
in {
  options.services.loki.settings = {
    httpListenPort = mkOption {
      type = port;
      description = "Port to listen on over HTTP";
      default = 9093;
    };
    grpcListenPort = mkOption {
      type = port;
      description = "Port to listen on over gRPC";
      default = 0;
    };
  };
  config = {
    services.loki = {
      #enable = true;
      configFile = pkgs.writeTextFile {
        name = "config.yaml";
        executable = false;
        text = toJSON {
          server = {
            http_listen_port = cfg.settings.httpListenPort;
            grpc_listen_port = cfg.settings.grpcListenPort;
          };
          positions = {
            filename = "/tmp/positions.yaml";
          };
          clients =
            mapAttrsToList (_: system: {
              url = "${access.getAddressFor system.config.name "lan"}:${toString system.config.exports.services.promtail.ports.default.port}";
            })
            promtailSystems;
          scrape_configs =
            mapAttrsToList (_: system: {
              job_name = "${system.config.name}-journal";
              journal = {
                max_age = "${toString (24 * 7)}h";
                labels = {
                  job = "systemd-journal";
                  host = system.config.name;
                };
              };
              relabel_configs = [
                {
                  source_labels = ["__journal__systemd_unit"];
                  target_label = "unit";
                }
              ];
            })
            promtailSystems;
        };
      };
    };
  };
}
