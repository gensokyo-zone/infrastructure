{
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkOptionDefault;
in {
  config.exports.services.dnsmasq = {
    systemConfig,
    config,
    ...
  }: {
    displayName = mkAlmostOptionDefault "Dnsmasq";
    id = mkAlmostOptionDefault "dns";
    nixos = {
      serviceAttr = "dnsmasq";
    };
    defaults.port.listen = mkAlmostOptionDefault "lan";
    ports = {
      default = {
        port = mkAlmostOptionDefault 53;
        transport = "udp";
        status = {
          enable = mkAlmostOptionDefault true;
          gatus = {
            protocol = "dns";
            settings = {
              dns = {
                query-type = mkOptionDefault "A";
                query-name = mkOptionDefault systemConfig.access.fqdn;
              };
              conditions = mkOptionDefault [
                "[BODY] == ${systemConfig.network.networks.local.address4}"
              ];
            };
          };
        };
      };
      tcp = {
        port = mkAlmostOptionDefault config.ports.default.port;
        transport = "tcp";
      };
    };
  };
}
