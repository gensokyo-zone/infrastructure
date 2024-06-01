{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.invidious = {config, ...}: {
    displayName = mkAlmostOptionDefault "Invidious";
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
    ports.default = {
      port = mkAlmostOptionDefault 3000;
      protocol = "http";
      status.enable = mkAlmostOptionDefault true;
    };
  };
}
