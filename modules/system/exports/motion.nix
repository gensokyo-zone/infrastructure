{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.motion = {config, ...}: {
    displayName = mkAlmostOptionDefault "Motion";
    nixos = {
      serviceAttr = "motion";
      assertions = let
        # in motion.conf, `0` represents the port being disabled
        configPort = port: if port.enable then port.port else 0;
      in mkIf config.enable [
        (nixosConfig: {
          assertion = configPort config.ports.default == nixosConfig.services.motion.settings.webcontrol_port or 0;
          message = "webcontrol port mismatch";
        })
        (nixosConfig: {
          assertion = configPort config.ports.stream == nixosConfig.services.motion.settings.stream_port or 0;
          message = "stream port mismatch";
        })
      ];
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = {
      default = {
        port = mkAlmostOptionDefault 8080;
        protocol = "http";
        status.enable = mkAlmostOptionDefault true;
      };
      stream = {
        port = mkAlmostOptionDefault 41081;
        protocol = "http";
        displayName = mkAlmostOptionDefault "Stream";
        #status.enable = mkAlmostOptionDefault true;
      };
    };
  };
}
