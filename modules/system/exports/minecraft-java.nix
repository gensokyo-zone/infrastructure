{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.minecraft = {config, ...}: let
    mkAssertion = f: nixosConfig: let
      cfg = nixosConfig.services.${config.nixos.serviceAttr};
    in
      f nixosConfig cfg;
  in {
    displayName = "Minecraft";
    nixos = {
      serviceAttr = "minecraft-java-server";
      assertions = mkIf config.enable [
        (mkAssertion (nixosConfig: cfg: {
          assertion = config.ports.default.port == cfg.port;
          message = "server-port mismatch";
        }))
        (mkAssertion (nixosConfig: cfg: {
          assertion = config.ports.rcon.enable == cfg.serverProperties.enable-rcon or false;
          message = "enable-rcon mismatch";
        }))
        (mkAssertion (nixosConfig: cfg: {
          assertion = (! cfg.serverProperties.enable-rcon or false) || config.ports.rcon.port == cfg.serverProperties."rcon.port" or 25575;
          message = "rcon.port mismatch";
        }))
        (mkAssertion (nixosConfig: cfg: {
          assertion = config.ports.query.enable == cfg.serverProperties.enable-query or false;
          message = "enable-query mismatch";
        }))
        (mkAssertion (nixosConfig: cfg: {
          assertion = (! cfg.serverProperties.enable-query or false) || config.ports.query.port == cfg.serverProperties."query.port" or 25565;
          message = "query.port mismatch";
        }))
      ];
    };
    defaults.port.listen = mkAlmostOptionDefault "local";
    ports = {
      default = {
        port = mkAlmostOptionDefault 25565;
        transport = "tcp";
      };
      rcon = {
        enable = mkAlmostOptionDefault false;
        port = mkAlmostOptionDefault 25575;
        transport = "tcp";
        listen = mkAlmostOptionDefault "int";
      };
      query = {
        enable = mkAlmostOptionDefault false;
        port = mkAlmostOptionDefault config.ports.default.port;
        transport = "udp";
      };
    };
  };
}
