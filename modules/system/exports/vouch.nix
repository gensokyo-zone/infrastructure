{lib, gensokyo-zone, ...}: let
  inherit (gensokyo-zone.lib) mapAlmostOptionDefaults mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.vouch-proxy = { config, ... }: {
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
    ports.default = mapAlmostOptionDefaults {
      port = 30746;
      protocol = "http";
    };
  };
}
