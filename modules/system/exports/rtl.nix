{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.rtl_tcp = {config, ...}: {
    id = mkAlmostOptionDefault "rtl";
    nixos = {
      serviceAttr = "rtl_tcp";
      assertions = let
        mkAssertion = f: nixosConfig: let
          cfg = nixosConfig.services.rtl_tcp;
        in
          f nixosConfig cfg;
      in
        mkIf config.enable [
          (mkAssertion (nixosConfig: cfg: {
            assertion = config.ports.tcp.port == cfg.port;
            message = "port mismatch";
          }))
        ];
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = {
      tcp = {
        port = mkAlmostOptionDefault 1234;
        transport = "tcp";
      };
    };
  };
}
