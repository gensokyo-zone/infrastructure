{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.octoprint = {config, ...}: {
    displayName = mkAlmostOptionDefault "OctoPrint";
    id = mkAlmostOptionDefault "print";
    nixos = {
      serviceAttr = "octoprint";
      assertions = let
        mkAssertion = f: nixosConfig: let
          cfg = nixosConfig.services.octoprint;
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
        port = mkAlmostOptionDefault 5000;
        protocol = "http";
        status.enable = mkAlmostOptionDefault true;
      };
    };
  };
}
