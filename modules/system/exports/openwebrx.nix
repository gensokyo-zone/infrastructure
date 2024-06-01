{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.openwebrx = {config, ...}: {
    displayName = mkAlmostOptionDefault "OpenWebRX";
    id = mkAlmostOptionDefault "webrx";
    nixos = {
      serviceAttr = "openwebrx";
      assertions = let
        mkAssertion = f: nixosConfig: let
          cfg = nixosConfig.services.openwebrx;
        in
          f nixosConfig cfg;
      in
        mkIf config.enable [
          (mkAssertion (nixosConfig: cfg: {
            assertion = config.ports.default.port == cfg.port;
            message = "port mismatch";
          }))
        ];
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = {
      default = {
        port = mkAlmostOptionDefault 8073;
        protocol = "http";
        status.enable = mkAlmostOptionDefault true;
      };
    };
  };
}
