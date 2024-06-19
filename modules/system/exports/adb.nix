{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.adb = {config, ...}: {
    displayName = mkAlmostOptionDefault "ADB";
    nixos = {
      serviceAttr = "adb";
      assertions = mkIf config.enable [
        (nixosConfig: {
          assertion = config.ports.default.port == nixosConfig.services.adb.port;
          message = "port mismatch";
        })
      ];
    };
    defaults.port.listen = mkAlmostOptionDefault "localhost";
    ports.default = {
      port = mkAlmostOptionDefault 5037;
      transport = "tcp";
    };
  };
}
