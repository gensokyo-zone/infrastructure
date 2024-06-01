{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
in {
  config.exports.services.motion = {config, ...}: {
    displayName = mkAlmostOptionDefault "Motion";
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = {
      default = {
        port = mkAlmostOptionDefault 8080;
        protocol = "http";
        status.enable = mkAlmostOptionDefault true;
      };
      stream = {
        port = mkAlmostOptionDefault 8081;
        protocol = "http";
        displayName = mkAlmostOptionDefault "Stream";
        status.enable = mkAlmostOptionDefault true;
      };
    };
  };
}
