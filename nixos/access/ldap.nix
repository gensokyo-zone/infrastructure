{
  config,
  lib,
  gensokyo-zone,
  access,
  ...
}:
let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkOptionDefault;
  inherit (config.services) nginx;
  portPlaintext = 389;
  portSsl = 636;
  system = access.systemForService "ldap";
  inherit (system.exports.services) ldap;
in {
  options.services.nginx.access.ldap = with lib.types; {
    domain = mkOption {
      type = str;
      default = "ldap.${config.networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "ldap.local.${config.networking.domain}";
    };
    intDomain = mkOption {
      type = str;
      default = "ldap.int.${config.networking.domain}";
    };
    tailDomain = mkOption {
      type = str;
      default = "ldap.tail.${config.networking.domain}";
    };
  };
  config = {
    services.nginx = {
      stream = {
        upstreams = let
          addr = mkAlmostOptionDefault (access.getAddressFor system.name "lan");
        in {
          ldap.servers.access = {
            inherit addr;
            port = mkOptionDefault ldap.ports.default.port;
          };
          ldaps = {
            enable = mkAlmostOptionDefault ldap.ports.ssl.enable;
            ssl.enable = mkAlmostOptionDefault true;
            servers.access = {
              inherit addr;
              port = mkOptionDefault ldap.ports.ssl.port;
            };
          };
        };
        servers.ldap = {
          listen = {
            ldap.port = mkOptionDefault portPlaintext;
            ldaps = {
              port = mkOptionDefault portSsl;
              ssl = true;
            };
          };
          proxy.upstream = mkAlmostOptionDefault (
            if nginx.stream.upstreams.ldaps.enable then "ldaps" else "ldap"
          );
        };
      };
    };

    networking.firewall = let
      inherit (nginx.stream.servers.ldap) listen;
    in {
      interfaces.local.allowedTCPPorts = [
        listen.ldap.port
      ];
      allowedTCPPorts = mkIf listen.ldaps.enable [
        listen.ldaps.port
      ];
    };
  };
}
