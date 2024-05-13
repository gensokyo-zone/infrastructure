{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.minecraft-bedrock-server = {config, ...}: let
    mkAssertion = f: nixosConfig: let
      cfg = nixosConfig.services.minecraft-bedrock-server;
    in
      f nixosConfig cfg;
  in {
    nixos = {
      serviceAttr = "minecraft-bedrock-server";
      assertions = mkIf config.enable [
        (mkAssertion (nixosConfig: cfg: {
          assertion = config.ports.default.port == cfg.serverProperties.server-port;
          message = "server-port mismatch";
        }))
        (mkAssertion (nixosConfig: cfg: {
          assertion = config.ports.v6.port == cfg.serverProperties.server-portv6;
          message = "server-portv6 mismatch";
        }))
      ];
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      default = {
        port = 19132;
        transport = "udp";
      };
      v6 = {
        port = 19133;
        transport = "udp";
      };
    };
  };
}
