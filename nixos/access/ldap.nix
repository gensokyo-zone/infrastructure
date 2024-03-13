{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.strings) concatMapStringsSep optionalString;
  inherit (lib.lists) optionals;
  inherit (config.services) tailscale;
  inherit (config.services.nginx) virtualHosts;
  inherit (config.networking.access) cidrForNetwork localaddrs;
  access = config.services.nginx.access.ldap;
  allows = let
    mkAllow = cidr: "allow ${cidr};";
    allowAddresses =
      cidrForNetwork.loopback.all
      ++ cidrForNetwork.local.all
      ++ optionals tailscale.enable cidrForNetwork.tail.all;
    allows =
      concatMapStringsSep "\n" mkAllow allowAddresses
      + optionalString localaddrs.enable ''
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
      default = 636;
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
        proxyPass = "${access.host}:${toString access.port}";
        proxySsl = optionalString (access.port == 636) ''
          proxy_ssl on;
          proxy_ssl_verify off;
        '';
      in
        mkIf access.enable (mkMerge [
          ''
            server {
              listen 0.0.0.0:389;
              listen [::]:389;
              ${allows}
              proxy_pass ${proxyPass};
              ${proxySsl}
            }
          ''
          (mkIf (access.useACMEHost != null) ''
            server {
              listen 0.0.0.0:636 ssl;
              listen [::]:636 ssl;
              ssl_certificate ${cert.directory}/fullchain.pem;
              ssl_certificate_key ${cert.directory}/key.pem;
              ssl_trusted_certificate ${cert.directory}/chain.pem;
              proxy_pass ${proxyPass};
              ${proxySsl}
            }
          '')
        ]);
    };

    networking.firewall = {
      interfaces.local.allowedTCPPorts = [
        389
      ];
      allowedTCPPorts = [
        636
      ];
    };
  };
}
