{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
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
      ];
    };
    ports = {
      default = {
        port = mkAlmostOptionDefault 8222;
        protocol = "http";
        status.enable = mkAlmostOptionDefault true;
      };
    };
  };
}
