{
  config,
  lib,
  ...
}:
let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.strings) concatMapStringsSep optionalString;
  inherit (config.services.nginx) virtualHosts;
  inherit (config.networking.access) cidrForNetwork localaddrs;
  access = config.services.nginx.access.ldap;
  portPlaintext = 389;
  portSsl = 636;
  allows = let
    mkAllow = cidr: "allow ${cidr};";
    allows = concatMapStringsSep "\n" mkAllow cidrForNetwork.allLocal.all + optionalString localaddrs.enable ''
      include ${localaddrs.stateDir}/*.nginx.conf;
    '';
  in ''
    ${allows}
    deny all;
  '';
in {
  options.services.nginx.access.ldap = with lib.types; {
    enable = mkEnableOption "LDAP proxy";
    host = mkOption {
      type = str;
    };
    domain = mkOption {
      type = str;
      default = "ldap.${config.networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "ldap.local.${config.networking.domain}";
    };
    tailDomain = mkOption {
      type = str;
      default = "ldap.tail.${config.networking.domain}";
    };
    port = mkOption {
      type = port;
      default = portSsl;
    };
    sslPort = mkOption {
      type = port;
      default = portSsl;
    };
    bind = {
      sslPort = mkOption {
        type = port;
        default = portSsl;
      };
      port = mkOption {
        type = port;
        default = portPlaintext;
      };
    };
    useACMEHost = mkOption {
      type = nullOr str;
      default = virtualHosts.${access.domain}.useACMEHost or null;
    };
  };
  config = {
    services.nginx = {
      streamConfig = let
        cert = config.security.acme.certs.${access.useACMEHost};
        proxySsl = port: optionalString (port == portSsl) ''
          proxy_ssl on;
          proxy_ssl_verify off;
        '';
      in mkIf access.enable (mkMerge [
        ''
          server {
            listen 0.0.0.0:${toString access.bind.port};
            listen [::]:${toString access.bind.port};
            ${allows}
            proxy_pass ${access.host}:${toString access.port};
            ${proxySsl access.port}
          }
        ''
        (mkIf (access.useACMEHost != null) ''
          server {
            listen 0.0.0.0:${toString access.bind.sslPort} ssl;
            listen [::]:${toString access.bind.sslPort} ssl;
            ssl_certificate ${cert.directory}/fullchain.pem;
            ssl_certificate_key ${cert.directory}/key.pem;
            ssl_trusted_certificate ${cert.directory}/chain.pem;
            proxy_pass ${access.host}:${toString access.sslPort};
            ${proxySsl access.sslPort}
          }
        '')
      ]);
    };

    networking.firewall = {
      interfaces.local.allowedTCPPorts = [
        access.bind.port
      ];
      allowedTCPPorts = [
        access.bind.sslPort
      ];
    };
  };
}
