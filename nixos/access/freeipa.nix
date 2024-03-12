{
  config,
  meta,
  lib,
  ...
}:
let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkBefore mkIf mkDefault;
  inherit (lib.strings) optionalString concatStringsSep;
  inherit (config.services) tailscale;
  inherit (config.services.nginx) virtualHosts;
  access = config.services.nginx.access.freeipa;
  inherit (config.services.nginx.access) ldap;
  extraConfig = ''
    ssl_verify_client optional_no_ca;
  '';
  locations' = domain: {
    "/" = {
      proxyPass = mkDefault access.proxyPass;
      recommendedProxySettings = false;
      extraConfig = ''
        proxy_set_header Host ${domain};
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Forwarded-Host $host;
        proxy_set_header X-Forwarded-Server $host;
        proxy_set_header X-SSL-CERT $ssl_client_escaped_cert;
        proxy_redirect https://${domain}/ $scheme://$host/;
      '';
    };
  };
  locations = locations' access.domain;
  caLocations = locations' access.caDomain;
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.access.ldap
  ];

  options.services.nginx.access.freeipa = with lib.types; {
    host = mkOption {
      type = str;
    };
    kerberos = {
      enable = mkEnableOption "proxy kerberos" // {
        default = true;
      };
      ports = {
        ticket = mkOption {
          type = port;
          default = 88;
        };
        ticket4 = mkOption {
          type = port;
          default = 4444;
        };
        kpasswd = mkOption {
          type = port;
          default = 749;
        };
      };
    };
    proxyPass = mkOption {
      type = str;
      default = let
        scheme = if access.port == 443 then "https" else "http";
      in "${scheme}://${access.host}:${toString access.port}";
    };
    domain = mkOption {
      type = str;
      default = "idp.${config.networking.domain}";
    };
    caDomain = mkOption {
      type = str;
      default = "idp-ca.${config.networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "freeipa.local.${config.networking.domain}";
    };
    tailDomain = mkOption {
      type = str;
      default = "freeipa.tail.${config.networking.domain}";
    };
    port = mkOption {
      type = port;
      default = 443;
    };
    ldapPort = mkOption {
      type = port;
      default = 636;
    };
    useACMEHost = mkOption {
      type = nullOr str;
      default = virtualHosts.${access.domain}.useACMEHost;
    };
  };
  config = {
    services.nginx = {
      access.ldap = {
        enable = mkDefault true;
        host = mkDefault access.host;
        port = mkDefault access.ldapPort;
        useACMEHost = mkDefault access.useACMEHost;
      };
      streamConfig = mkIf access.kerberos.enable ''
        server {
          listen 0.0.0.0:${toString access.kerberos.ports.ticket};
          listen [::]:${toString access.kerberos.ports.ticket};
          listen 0.0.0.0:${toString access.kerberos.ports.ticket} udp;
          listen [::]:${toString access.kerberos.ports.ticket} udp;
          proxy_pass ${access.host}:${toString access.kerberos.ports.ticket};
        }
        server {
          listen 0.0.0.0:${toString access.kerberos.ports.ticket4} udp;
          listen [::]:${toString access.kerberos.ports.ticket4} udp;
          proxy_pass ${access.host}:${toString access.kerberos.ports.ticket4};
        }
        server {
          listen 0.0.0.0:${toString access.kerberos.ports.kpasswd};
          listen [::]:${toString access.kerberos.ports.kpasswd};
          listen 0.0.0.0:${toString access.kerberos.ports.kpasswd} udp;
          listen [::]:${toString access.kerberos.ports.kpasswd} udp;
          proxy_pass ${access.host}:${toString access.kerberos.ports.kpasswd};
        }
      '';
      virtualHosts = {
        ${access.domain} = {
          inherit locations extraConfig;
        };
        ${access.caDomain} = {
          locations = caLocations;
          inherit extraConfig;
        };
        ${access.localDomain} = {
          inherit (virtualHosts.${access.domain}) useACMEHost;
          addSSL = mkDefault (access.useACMEHost != null || virtualHosts.${access.domain}.forceSSL);
          local.enable = true;
          inherit locations;
        };
        ${access.tailDomain} = mkIf tailscale.enable {
          inherit (virtualHosts.${access.domain}) useACMEHost;
          addSSL = mkDefault (access.useACMEHost != null || virtualHosts.${access.domain}.forceSSL);
          local.enable = true;
          inherit locations;
        };
        ${ldap.domain} = { config, ... }: {
          useACMEHost = mkDefault virtualHosts.${access.domain}.useACMEHost;
          addSSL = mkDefault (config.useACMEHost != null);
          globalRedirect = access.domain;
        };
        ${ldap.localDomain} = {
          inherit (virtualHosts.${ldap.domain}) useACMEHost addSSL;
          globalRedirect = access.localDomain;
          local.enable = true;
        };
        ${ldap.tailDomain} = mkIf tailscale.enable {
          inherit (virtualHosts.${ldap.domain}) useACMEHost addSSL;
          globalRedirect = access.tailDomain;
          local.enable = true;
        };
      };
    };

    networking.firewall = {
      allowedTCPPorts = mkIf access.kerberos.enable [
        access.kerberos.ports.ticket
        access.kerberos.ports.kpasswd
      ];
      allowedUDPPorts = mkIf access.kerberos.enable [
        access.kerberos.ports.ticket
        access.kerberos.ports.ticket4
        access.kerberos.ports.kpasswd
      ];
    };
  };
}
