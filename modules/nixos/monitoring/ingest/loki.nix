{
  config,
  lib,
  access,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone) systems;
  inherit (gensokyo-zone.lib) mapOptionDefaults;
  inherit (lib.modules) mkIf mkOptionDefault;
  inherit (lib.attrsets) filterAttrs mapAttrsToList;
  promtailSystems =
    filterAttrs (
      _: system:
        system.access.online.enable
        && system.exports.services.promtail.enable
    )
    systems;
  cfg = config.services.loki;
in {
  config = {
    services.loki = {
      configuration = {
        server = {
          http_listen_port = mkOptionDefault 9093;
          grpc_listen_port = mkOptionDefault 0;
        };
        limits_config = mapOptionDefaults {
          ingestion_rate_mb = 256;
          ingestion_burst_size_mb = 512;
          max_label_value_length = 8192 * 4;
          max_label_names_per_series = 128;
          max_entries_limit_per_query = 1000000;
          #cardinality_limit: 200000
          max_line_size = "512KB";
          per_stream_rate_limit = "128MB";
          per_stream_rate_limit_burst = "256MB";
          reject_old_samples = true;
          reject_old_samples_max_age = "${toString (24 * 9)}h";
        };
        # https://grafana.com/docs/loki/latest/configure/examples/configuration-examples/#1-local-configuration-exampleyaml
        auth_enabled = mkOptionDefault false;
        common = {
          ring = {
            instance_addr = mkOptionDefault "127.0.0.1";
            kvstore.store = mkOptionDefault "inmemory";
          };
          replication_factor = 1;
          path_prefix = mkOptionDefault cfg.dataDir;
        };
        schema_config.configs = [
          {
            from = "2020-05-15";
            store = "tsdb";
            object_store = "filesystem";
            schema = "v13";
            index = {
              prefix = "index_";
              period = "24h";
            };
          }
        ];
        storage_config.filesystem.directory = mkOptionDefault "${cfg.dataDir}/chunks";
      };
    };
    networking.firewall.interfaces.local = let
      inherit (cfg.configuration) server;
    in
      mkIf cfg.enable {
        allowedTCPPorts = [
          # for nodes on the lan outside of reisen...
          server.http_listen_port
          (mkIf (server.grpc_listen_port != 0) server.grpc_listen_port)
        ];
      };
  };
}
