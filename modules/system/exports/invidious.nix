{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.invidious = {config, ...}: {
    id = mkAlmostOptionDefault "yt";
    nixos = {
      serviceAttr = "invidious";
      assertions = mkIf config.enable [
        (nixosConfig: {
          assertion = config.ports.default.port == nixosConfig.services.invidious.port;
          message = "port mismatch";
        })
      ];
    };
    ports.default = mapAlmostOptionDefaults {
      port = 3000;
      protocol = "http";
    };
  };
}
