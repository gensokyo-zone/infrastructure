{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.postgresql = {config, ...}: let
    mkAssertion = f: nixosConfig: let
      cfg = nixosConfig.services.postgresql;
    in
      f nixosConfig cfg;
  in {
    nixos = {
      serviceAttr = "postgresql";
      assertions = mkIf config.enable [
        (mkAssertion (nixosConfig: cfg: {
          assertion = config.ports.default.port == cfg.settings.port;
          message = "port mismatch";
        }))
        (mkAssertion (nixosConfig: cfg: {
          assertion = config.ports.default.enable == cfg.enableTCPIP;
          message = "enableTCPIP mismatch";
        }))
      ];
    };
    ports.default = mapAlmostOptionDefaults {
      port = 5432;
      transport = "tcp";
    };
  };
}
