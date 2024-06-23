{
  config,
  lib,
  access,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone) systems;
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
  };
}
