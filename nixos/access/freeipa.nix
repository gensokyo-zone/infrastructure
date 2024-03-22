{
  config,
  meta,
  lib,
  ...
}:
let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkDefault;
  inherit (lib.strings) optionalString concatStringsSep;
  inherit (config.services) tailscale;
  inherit (config.services) nginx;
  inherit (nginx) virtualHosts;
  access = nginx.access.freeipa;
  inherit (nginx.access) ldap;
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

        proxy_ssl_server_name on;
        proxy_ssl_name ${domain};

        set $x_referer $http_referer;
        if ($x_referer ~ "^https://([^/]*)/(.*)$") {
          set $x_referer_host $1;
          set $x_referer_path $2;
        }
        if ($x_referer_host = $host) {
          set $x_referer "https://${domain}/$x_referer_path";
        }
        proxy_set_header Referer $x_referer;
      '';
    };
  };
  locations = locations' virtualHosts.freeipa.serverName;
  caLocations = locations' virtualHosts.freeipa'ca.serverName;
  kTLS = mkDefault true;
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
    preread = {
      enable = mkEnableOption "ssl preread" // {
        default = true;
      };
      port = mkOption {
        type = port;
        default = 444;
      };
      ldapPort = mkOption {
        type = port;
        default = 637;
      };
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
    port = mkOption {
      type = port;
      default = 443;
    };
    ldapPort = mkOption {
      type = port;
      default = 636;
    };
  };
  config = {
    services.nginx = {
      access.ldap = {
        enable = mkDefault true;
        host = mkDefault access.host;
        port = mkDefault 389;
        sslPort = mkDefault access.ldapPort;
        useACMEHost = mkDefault virtualHosts.freeipa.ssl.cert.name;
        bind.sslPort = mkIf access.preread.enable (mkDefault access.preread.ldapPort);
      };
      resolver.addresses = mkIf access.preread.enable (mkMerge [
        (mkDefault [ "[::1]:5353" "127.0.0.1:5353" ])
        (mkIf config.systemd.network.enable [ "127.0.0.53" ])
      ]);
      defaultSSLListenPort = mkIf access.preread.enable access.preread.port;
      streamConfig = let
        upstreams' = {
          freeipa = "${access.host}:${toString access.port}";
          ldap_freeipa = "${nginx.access.ldap.host}:${toString nginx.access.ldap.sslPort}";
          ldap = "localhost:${toString nginx.access.ldap.bind.sslPort}";
          nginx = "localhost:${toString nginx.defaultSSLListenPort}";
          samba = if config.services.samba.enable
            then "localhost:445"
            else "smb.local.${config.networking.domain}:445";
        };
        upstreams = builtins.mapAttrs (name: _: name) upstreams';
        preread = ''
          upstream freeipa {
            server ${upstreams'.freeipa};
          }
          upstream ldap_freeipa {
            server ${upstreams'.ldap_freeipa};
          }
          upstream ldap {
            server ${upstreams'.ldap};
          }
          upstream samba {
            server ${upstreams'.samba};
          }
          upstream nginx {
            server ${upstreams'.nginx};
          }
          map $ssl_preread_server_name $ssl_server_name {
            hostnames;
            ${virtualHosts.freeipa.serverName} ${upstreams.freeipa};
            ${virtualHosts.freeipa'ca.serverName} ${upstreams.freeipa};
            ${nginx.access.ldap.domain} ${upstreams.ldap};
            ${nginx.access.ldap.localDomain} ${upstreams.ldap};
            ${nginx.access.ldap.tailDomain} ${upstreams.ldap};
            default ${upstreams.nginx};
          }
          map $ssl_preread_alpn_protocols $https_upstream {
            ~\bsmb\b ${upstreams.samba};
            # XXX: if only there were an ldap protocol id...
            default $ssl_server_name;
          }

          server {
            listen 0.0.0.0:443;
            listen [::]:443;
            ssl_preread on;
            proxy_pass $https_upstream;
          }

          map $ssl_preread_server_name $ldap_upstream {
            hostnames;
            ${virtualHosts.freeipa.serverName} ${upstreams.ldap_freeipa};
            default ${upstreams.ldap};
          }

          server {
            listen 0.0.0.0:636;
            listen [::]:636;
            ssl_preread on;
            proxy_pass $ldap_upstream;
          }
        '';
        kerberos = ''
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
      in mkMerge [
        (mkIf access.preread.enable preread)
        (mkIf access.kerberos.enable kerberos)
      ];
      virtualHosts = let
        name.shortServer = mkDefault "freeipa";
      in {
        freeipa = {
          name.shortServer = mkDefault "idp";
          inherit locations extraConfig kTLS;
          ssl.force = mkDefault true;
        };
        freeipa'web = {
          ssl = {
            force = mkDefault virtualHosts.freeipa.ssl.force;
            cert.copyFromVhost = "freeipa";
          };
          inherit name locations extraConfig kTLS;
        };
        freeipa'ca = {
          name.shortServer = mkDefault "idp-ca";
          locations = caLocations;
          ssl = {
            force = mkDefault virtualHosts.freeipa.ssl.force;
            cert.copyFromVhost = "freeipa";
          };
          inherit extraConfig kTLS;
        };
        freeipa'web'local = {
          ssl.cert.copyFromVhost = "freeipa'web";
          local.enable = true;
          inherit name locations kTLS;
        };
        freeipa'ldap = {
          serverName = mkDefault ldap.domain;
          ssl.cert.copyFromVhost = "freeipa";
          globalRedirect = virtualHosts.freeipa'web.serverName;
        };
        freeipa'ldap'local = {
          serverName = mkDefault ldap.localDomain;
          ssl.cert.copyFromVhost = "freeipa'ldap";
          globalRedirect = virtualHosts.freeipa'web'local.serverName;
          local.enable = true;
        };
        freeipa'ldap'tail = {
          enable = mkDefault tailscale.enable;
          serverName = mkDefault ldap.tailDomain;
          ssl.cert.copyFromVhost = "freeipa'ldap'local";
          globalRedirect = virtualHosts.freeipa'web'local.name.tailscaleName;
          local.enable = true;
        };
      };
    };

    networking.firewall = {
      allowedTCPPorts = mkMerge [
        (mkIf access.kerberos.enable [
          access.kerberos.ports.ticket
          access.kerberos.ports.kpasswd
        ])
        (mkIf access.preread.enable [
          636
        ])
      ];
      allowedUDPPorts = mkIf access.kerberos.enable [
        access.kerberos.ports.ticket
        access.kerberos.ports.ticket4
        access.kerberos.ports.kpasswd
      ];
    };
  };
}
