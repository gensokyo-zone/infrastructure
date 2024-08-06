{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.moonraker = {config, ...}: {
    displayName = mkAlmostOptionDefault "Moonraker";
    id = mkAlmostOptionDefault "moonraker";
    nixos = {
      serviceAttr = "moonraker";
      assertions = let
        mkAssertion = f: nixosConfig: let
          cfg = nixosConfig.services.moonraker;
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
        port = mkAlmostOptionDefault 7125;
        protocol = "http";
        status.enable = mkAlmostOptionDefault true;
      };
    };
  };
}
