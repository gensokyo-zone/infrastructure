{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.barcodebuddy = {config, ...}: {
    nixos = {
      serviceAttr = "barcodebuddy";
      assertions = mkIf config.enable [
        (nixosConfig: let
          cfg = nixosConfig.services.barcodebuddy;
        in {
          assertion = config.ports.screen.port == cfg.screen.websocketPort;
          message = "screen.websocketPort mismatch";
        })
      ];
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports.screen = mapAlmostOptionDefaults {
      port = 47631;
      transport = "tcp";
    };
  };
}
