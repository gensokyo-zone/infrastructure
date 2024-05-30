{
  config,
  system,
  access,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkOptionDefault;
  cfg = config.services.promtail;
in {
  config.services.promtail = {
    configuration = {
      server = {
        http_listen_port = mkOptionDefault 9094;
        grpc_listen_port = mkOptionDefault 0;
      };
      clients = let
        baseUrl = access.proxyUrlFor { serviceName = "loki"; };
      in [
        {
          url = "${baseUrl}/loki/api/v1/push";
        }
      ];
      scrape_configs = [
        {
          job_name = "${system.name}-journald";
          journal = {
            max_age = "${toString (24 * 7)}h";
            labels = {
              job = "systemd-journald";
              system = system.name;
              host = config.networking.fqdn;
            };
          };
          relabel_configs = [
            {
              source_labels = ["__journal__systemd_unit"];
              target_label = "unit";
            }
          ];
        }
      ];
    };
  };
  config.networking.firewall.interfaces.lan = let
    inherit (cfg.configuration) server;
  in
    mkIf cfg.enable {
      allowedTCPPorts = [
        server.http_listen_port
        (mkIf (server.grpc_listen_port != 0) server.grpc_listen_port)
      ];
    };
}
