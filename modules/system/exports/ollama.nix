{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  config.exports.services.ollama = {config, ...}: {
    displayName = mkAlmostOptionDefault "Ollama";
    id = mkAlmostOptionDefault "ollama";
    nixos = {
      serviceAttr = "ollama";
      assertions = mkIf config.enable [
        (nixosConfig: {
          assertion = config.ports.default.port == nixosConfig.services.ollama.port;
          message = "port mismatch";
        })
      ];
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = {
      default = {
        port = mkAlmostOptionDefault 11434;
        protocol = "http";
        status.enable = mkAlmostOptionDefault true;
      };
    };
  };
}
