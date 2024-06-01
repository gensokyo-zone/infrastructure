{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
in {
  config.exports.services.ldap = {config, ...}: {
    displayName = mkAlmostOptionDefault "LDAP";
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = {
      default = {
        port = mkAlmostOptionDefault 389;
        transport = "tcp";
        starttls = mkAlmostOptionDefault true;
        status.enable = mkAlmostOptionDefault true;
      };
      ssl = {
        port = mkAlmostOptionDefault 636;
        ssl = true;
        listen = "wan";
        status.enable = mkAlmostOptionDefault config.ports.default.status.enable;
      };
    };
  };
}
