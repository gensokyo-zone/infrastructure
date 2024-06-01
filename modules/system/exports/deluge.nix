{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.deluge = {config, ...}: {
    displayName = mkAlmostOptionDefault "Deluge";
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
    ports = let
      gatus.client.network = mkAlmostOptionDefault "ip4";
    in {
      default = {
        port = mkAlmostOptionDefault 58846;
        transport = "tcp";
        status = {
          inherit gatus;
        };
      };
      web = {
        port = mkAlmostOptionDefault 8112;
        protocol = "http";
        status = {
          inherit gatus;
          enable = mkAlmostOptionDefault true;
        };
      };
    };
  };
}
