{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.taskchampion = {config, ...}: let
    mkAssertion = f: nixosConfig: let
      cfg = nixosConfig.services.${config.nixos.serviceAttr};
    in
      f nixosConfig cfg;
  in {
    displayName = "TaskChampion";
    nixos = {
      serviceAttr = "taskchampion-sync-server";
      assertions = mkIf config.enable [
        (mkAssertion (nixosConfig: cfg: {
          assertion = config.ports.default.port == cfg.port;
          message = "server-port mismatch";
        }))
      ];
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports.default = {
      port = mkAlmostOptionDefault 10222;
      protocol = "http";
      status = {
        enable = mkAlmostOptionDefault true;
        gatus.client.network = mkAlmostOptionDefault "ip4";
      };
    };
  };
}
