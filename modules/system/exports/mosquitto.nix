{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  inherit (lib.lists) all imap0;
  inherit (lib.trivial) id;
in {
  config.exports.services.mosquitto = {config, ...}: {
    displayName = mkAlmostOptionDefault "Mosquitto";
    id = mkAlmostOptionDefault "mqtt";
    nixos = {
      serviceAttr = "mosquitto";
      assertions = mkIf config.enable [
        (nixosConfig: let
          cfg = nixosConfig.services.mosquitto;
          portName = i:
            if i == 0
            then "default"
            else "listener${toString i}";
          mkAssertPort = i: listener: config.ports.${portName i}.port or null == listener.port;
        in {
          assertion = all id (imap0 mkAssertPort cfg.listeners);
          message = "port mismatch";
        })
      ];
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = {
      default = {
        port = mkAlmostOptionDefault 1883;
        transport = "tcp";
        status.enable = mkAlmostOptionDefault true;
      };
      ssl = {
        enable = mkAlmostOptionDefault false;
        port = mkAlmostOptionDefault 8883;
        ssl = true;
        status.enable = mkAlmostOptionDefault config.ports.default.status.enable;
      };
    };
  };
}
