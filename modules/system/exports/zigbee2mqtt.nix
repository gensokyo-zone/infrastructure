{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.zigbee2mqtt = {config, ...}: {
    id = mkAlmostOptionDefault "z2m";
    displayName = mkAlmostOptionDefault "Zigbee2MQTT";
    nixos = {
      serviceAttr = "zigbee2mqtt";
      assertions = mkIf config.enable [
        (nixosConfig: {
          assertion = config.ports.default.port == nixosConfig.services.zigbee2mqtt.settings.frontend.port;
          message = "port mismatch";
        })
      ];
    };
    ports.default = {
      port = mkAlmostOptionDefault 8072;
      protocol = "http";
      status.enable = true;
    };
  };
}
