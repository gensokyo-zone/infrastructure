{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.syncplay = {config, ...}: {
    displayName = mkAlmostOptionDefault "Syncplay";
    nixos = {
      serviceAttr = "syncplay";
      assertions = mkIf config.enable [
        (nixosConfig: {
          assertion = config.ports.default.port == nixosConfig.services.syncplay.port;
          message = "port mismatch";
        })
      ];
    };
    ports.default = {
      port = mkAlmostOptionDefault 8999;
      protocol = "tcp";
    };
  };
}
