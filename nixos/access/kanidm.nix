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
  inherit (config.networking.access) cidrForNetwork;
  cfg = config.services.kanidm;
  access = config.services.nginx.access.kanidm;
  proxyPass = mkDefault "http://${access.host}:${toString access.port}";
  locations = {
    "/" = {
      inherit proxyPass;
    };
    "=/ca.pem" = {
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
    };
    localDomain = mkOption {
      type = str;
      default = "id.local.${config.networking.domain}";
    };
    port = mkOption {
      type = port;
    };
    ldapPort = mkOption {
      type = port;
    };
  };
  config = {
    services.nginx = {
      access.kanidm = mkIf cfg.enableServer {
        domain = mkOptionDefault cfg.server.frontend.domain;
        host = mkOptionDefault "localhost";
        port = mkOptionDefault cfg.server.frontend.port;
        ldapPort = mkOptionDefault cfg.server.ldap.port;
      };
      streamConfig = ''
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
          ssl_certificate ${cfg.serverSettings.tls_chain};
          ssl_certificate_key ${cfg.serverSettings.tls_key};
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
          local.enable = true;
          inherit locations;
        };
        "id.tail.${config.networking.domain}" = mkIf config.services.tailscale.enable {
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
