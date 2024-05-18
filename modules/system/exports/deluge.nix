{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  inherit (lib.attrsets) mapAttrs;
in {
  config.exports.services.deluge = {config, ...}: {
    nixos = {
      serviceAttr = "deluge";
      assertions = let
        mkAssertion = f: nixosConfig: let
          cfg = nixosConfig.services.deluge;
        in
          f nixosConfig cfg;
      in
        mkIf config.enable [
          (mkAssertion (nixosConfig: cfg: {
            assertion = config.ports.default.port == cfg.config.daemon_port;
            message = "config.daemon_port mismatch";
          }))
          (mkAssertion (nixosConfig: cfg: {
            assertion = config.ports.web.port == cfg.web.port;
            message = "web.port mismatch";
          }))
          (mkAssertion (nixosConfig: cfg: {
            assertion = config.ports.web.enable == cfg.web.enable;
            message = "web.enable mismatch";
          }))
        ];
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = mapAttrs (_: mapAlmostOptionDefaults) {
      default = {
        port = 58846;
        transport = "tcp";
      };
      web = {
        port = 8112;
        protocol = "http";
      };
    };
  };
}
