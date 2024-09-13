{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
  wyomingService = {config, ...}: {
    nixos = {
      serviceAttrPath = ["services" "wyoming" config.name];
      assertions = [
        (nixosConfig: let
          service = nixosConfig.services.wyoming.${config.name};
          cfg = service.servers.${config.id} or service;
        in {
          assertion = (! cfg ? enable) || (config.enable == cfg.enable);
          message = "enable mismatch";
        })
        (mkIf config.enable (nixosConfig: let
          service = nixosConfig.services.wyoming.${config.name};
          cfg = service.servers.${config.id} or service;
        in {
          assertion = ! cfg.enable or false || config.ports.default.port == cfg.port or null;
          message = "port mismatch";
        }))
      ];
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = {
      default = {
        transport = "tcp";
      };
    };
  };
in {
  config.exports.services = {
    faster-whisper = {config, ...}: {
      imports = [wyomingService];
      displayName = mkAlmostOptionDefault "Wyoming Whisper";
      id = mkAlmostOptionDefault "whisper";
      ports.default.port = mkAlmostOptionDefault 10300;
    };
    piper = {config, ...}: {
      imports = [wyomingService];
      displayName = mkAlmostOptionDefault "Wyoming Piper";
      id = mkAlmostOptionDefault "piper";
      ports.default.port = mkAlmostOptionDefault 10200;
    };
    openwakeword = {config, ...}: {
      imports = [wyomingService];
      displayName = mkAlmostOptionDefault "Wyoming openWakeWord";
      ports.default.port = mkAlmostOptionDefault 10400;
    };
    satellite = {config, ...}: {
      imports = [wyomingService];
      displayName = mkAlmostOptionDefault "Wyoming Satellite";
      ports.default.port = mkAlmostOptionDefault 10700;
    };
  };
}
