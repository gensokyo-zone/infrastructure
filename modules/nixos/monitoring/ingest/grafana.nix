{
  config,
  systemConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
  cfg = config.services.grafana;
  service = systemConfig.exports.services.grafana;
in {
  services.grafana = {
    settings.server = {
      domain = mkDefault config.networking.domain;
      http_port = mkDefault 9092;
      http_addr = mkDefault "::";
      root_url = mkDefault "https://${service.id}.${cfg.settings.server.domain}";
    };
    settings.security.secret_key = mkDefault (lib.warn "default grafana key in use!" "SW2YcwTIb9zpOOhoPsMm");
  };
}
