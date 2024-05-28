{
  config,
  lib,
  ...
}: let
  inherit (builtins) toJSON toString;
  inherit (lib.options) mkOption;
  inherit (lib.types) port;
  cfg = config.services.promtail;
in {
  options.services.promtail.settings = {
    httpListenPort = mkOption {
      type = port;
      description = "Port to listen on over HTTP";
      default = 9094;
    };
  };
  config.services.promtail = {
    extraFlags = [
      "--server.http-listen-port=${toString cfg.settings.httpListenPort}"
    ];
  };
}
