{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrs;
  inherit (lib.lists) all imap0;
  inherit (lib.trivial) id;
in {
  config.exports.services.mosquitto = {config, ...}: {
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
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      default = {
        port = 1883;
        transport = "tcp";
      };
      ssl = {
        enable = false;
        port = 8883;
        ssl = true;
      };
    };
  };
}
