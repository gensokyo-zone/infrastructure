{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.vouch-proxy = {config, ...}: {
    displayName = mkAlmostOptionDefault "Vouch Proxy";
    id = mkAlmostOptionDefault "login";
    defaults.port.listen = mkAlmostOptionDefault "localhost";
    nixos = {
      serviceAttr = "vouch-proxy";
      assertions = mkIf config.enable [
        (nixosConfig: {
          assertion = config.ports.default.port == nixosConfig.services.vouch-proxy.settings.vouch.port;
          message = "port mismatch";
        })
      ];
    };
    ports.default = {
      port = mkAlmostOptionDefault 30746;
      protocol = "http";
      status = {
        enable = mkAlmostOptionDefault true;
        gatus.http = {
          #path = "/validate";
          statusCondition = mkAlmostOptionDefault "[STATUS] == 404";
        };
      };
    };
  };
}
