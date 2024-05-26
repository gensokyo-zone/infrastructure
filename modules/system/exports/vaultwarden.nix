{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.vaultwarden = {config, ...}: {
    id = mkAlmostOptionDefault "bw";
    defaults.port.listen = mkAlmostOptionDefault "lan";
    nixos = {
      serviceAttr = "vaultwarden";
      assertions = mkIf config.enable [
        (nixosConfig: {
          assertion = config.ports.default.port == nixosConfig.services.vaultwarden.port;
          message = "port mismatch";
        })
        (nixosConfig: {
          assertion = nixosConfig.services.vaultwarden.websocketPort == null || config.ports.websocket.port == nixosConfig.services.vaultwarden.websocketPort;
          message = "websocketPort mismatch";
        })
        (nixosConfig: {
          assertion = config.ports.websocket.enable == (nixosConfig.services.vaultwarden.websocketPort != null);
          message = "websocketPort enable mismatch";
        })
      ];
    };
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      default = {
        port = 8222;
        protocol = "http";
      };
      websocket = {
        port = 8223;
        protocol = "http";
      };
    };
  };
}
