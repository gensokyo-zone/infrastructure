{
  config,
  lib,
  ...
}:
let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.strings) concatMapStringsSep;
  inherit (lib.lists) optionals;
  inherit (config.services) tailscale;
  inherit (config.services.nginx) virtualHosts;
  inherit (config.networking.access) cidrForNetwork;
  cfg = config.services.kanidm;
  access = config.services.nginx.access.kanidm;
  proxyPass = mkDefault "https://${access.host}:${toString access.port}";
  locations = {
    "/" = {
      inherit proxyPass;
    };
    "=/ca.pem" = mkIf cfg.server.unencrypted.enable {
      alias = "${cfg.server.unencrypted.package.ca}";
    };
  };
  allows = let
    mkAllow = cidr: "allow ${cidr};";
    allowAddresses =
      cidrForNetwork.loopback.all
      ++ cidrForNetwork.local.all
      ++ optionals tailscale.enable cidrForNetwork.tail.all;
    allows = concatMapStringsSep "\n" mkAllow allowAddresses;
  in ''
    ${allows}
    deny all;
  '';
in {
  options.services.nginx.access.kanidm = with lib.types; {
    host = mkOption {
      type = str;
    };
    domain = mkOption {
      type = str;
      default = "id.${config.networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "id.local.${config.networking.domain}";
    };
    tailDomain = mkOption {
      type = str;
      default = "id.tail.${config.networking.domain}";
    };
    ldapDomain = mkOption {
      type = str;
      default = "ldap.${config.networking.domain}";
    };
    ldapLocalDomain = mkOption {
      type = str;
      default = "ldap.local.${config.networking.domain}";
    };
    ldapTailDomain = mkOption {
      type = str;
      default = "ldap.tail.${config.networking.domain}";
    };
    port = mkOption {
      type = port;
    };
    ldapPort = mkOption {
      type = port;
    };
    ldapEnable = mkOption {
      type = bool;
      default = true;
    };
    useACMEHost = mkOption {
      type = nullOr str;
      default = virtualHosts.${access.domain}.useACMEHost;
    };
  };
  config = {
    services.nginx = {
      access.kanidm = mkIf cfg.enableServer {
        domain = mkOptionDefault cfg.server.frontend.domain;
        host = mkOptionDefault "localhost";
        port = mkOptionDefault cfg.server.frontend.port;
        ldapPort = mkOptionDefault cfg.server.ldap.port;
        ldapEnable = mkDefault cfg.server.ldap.enable;
      };
      streamConfig = let
        inherit (config.security.acme) certs;
        sslConfig = if access.useACMEHost != null then ''
          ssl_certificate ${certs.${access.useACMEHost}.directory}/fullchain.pem;
          ssl_certificate_key ${certs.${access.useACMEHost}.directory}/key.pem;
          ssl_trusted_certificate ${certs.${access.useACMEHost}.directory}/chain.pem;
        '' else ''
          ssl_certificate ${cfg.serverSettings.tls_chain};
          ssl_certificate_key ${cfg.serverSettings.tls_key};
        '';
      in mkIf access.ldapEnable ''
        server {
          listen 0.0.0.0:389;
          listen [::]:389;
          ${allows}
          proxy_pass ${access.host}:${toString access.ldapPort};
          proxy_ssl on;
          proxy_ssl_verify off;
        }
        server {
          listen 0.0.0.0:636 ssl;
          listen [::]:636 ssl;
          ${sslConfig}
          proxy_pass ${access.host}:${toString access.ldapPort};
          proxy_ssl on;
          proxy_ssl_verify off;
        }
      '';

      virtualHosts = {
        ${access.domain} = {
          inherit locations;
        };
        ${access.localDomain} = {
          inherit (virtualHosts.${access.domain}) useACMEHost;
          addSSL = mkDefault (access.useACMEHost != null || virtualHosts.${access.domain}.forceSSL);
          local.enable = true;
          inherit locations;
        };
        ${access.tailDomain} = mkIf config.services.tailscale.enable {
          inherit (virtualHosts.${access.domain}) useACMEHost;
          addSSL = mkDefault (access.useACMEHost != null || virtualHosts.${access.domain}.forceSSL);
          local.enable = true;
          inherit locations;
        };
      };
    };

    services.kanidm.server.unencrypted.domain = mkMerge [
      [
        access.localDomain
        config.networking.fqdn
        config.networking.access.hostnameForNetwork.local
      ]
      (mkIf config.services.tailscale.enable [
        "id.tail.${config.networking.domain}"
        config.networking.access.hostnameForNetwork.tail
      ])
    ];

    networking.firewall.allowedTCPPorts = [
      389 636
    ];
  };
}
