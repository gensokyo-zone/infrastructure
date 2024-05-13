{
  config,
  lib,
  gensokyo-zone,
  access,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkOptionDefault;
  inherit (config.services) nginx;
  portPlaintext = 389;
  portSsl = 636;
  upstreamName = "ldap'access";
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
        upstreams = {
          ${upstreamName}.servers = {
            ldaps = {
              accessService = {
                inherit (nginx.stream.upstreams.ldaps.servers.access.accessService) system name id port;
              };
            };
            ldap = {upstream, ...}: {
              enable = mkIf upstream.servers.ldaps.enable false;
              accessService = {
                inherit (nginx.stream.upstreams.ldap.servers.access.accessService) system name id port;
              };
            };
          };
          ldap.servers.access = {
            accessService = {
              name = "ldap";
            };
          };
          ldaps = {config, ...}: {
            enable = mkAlmostOptionDefault config.servers.access.enable;
            servers.access = {
              accessService = {
                name = "ldap";
                port = "ssl";
              };
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
          proxy.upstream = mkAlmostOptionDefault upstreamName;
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
