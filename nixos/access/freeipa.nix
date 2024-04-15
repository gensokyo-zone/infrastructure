{
  config,
  meta,
  lib,
  gensokyo-zone,
  ...
}:
let
  inherit (gensokyo-zone.lib) mkAddress6;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
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
          default = 464;
        };
        kadmin = mkOption {
          type = port;
          default = 749;
        };
      };
    };
    proxyPass = mkOption {
      type = str;
      default = let
        scheme = if access.port == 443 then "https" else "http";
      in "${scheme}://${mkAddress6 access.host}:${toString access.port}";
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
      access.freeipa = {
        host = mkOptionDefault (config.lib.access.getAddressFor (config.lib.access.systemForService "freeipa").name "lan");
      };
      resolver.addresses = mkIf access.preread.enable (mkMerge [
        (mkDefault [ "[::1]:5353" "127.0.0.1:5353" ])
        (mkIf config.systemd.network.enable [ "127.0.0.53" ])
      ]);
      defaultSSLListenPort = mkIf access.preread.enable access.preread.port;
      stream = let
        prereadConf = {
          upstreams = {
            freeipa = {
              ssl.enable = true;
              servers.access = let
                system = config.lib.access.systemForService "freeipa";
                inherit (system.exports.services) freeipa;
              in {
                addr = mkDefault (config.lib.access.getAddressFor system.name "lan");
                port = mkOptionDefault freeipa.ports.default.port;
              };
            };
            ldaps_access = {
              ssl.enable = true;
              servers.access = {
                addr = mkDefault "localhost";
                port = mkOptionDefault nginx.stream.servers.ldap.listen.ldaps.port;
              };
            };
            nginx = {
              ssl.enable = true;
              servers.access = {
                addr = mkDefault "localhost";
                port = mkOptionDefault nginx.defaultSSLListenPort;
              };
            };
          };
          servers = {
            preread'https = {
              listen = {
                https.port = 443;
              };
              ssl.preread.enable = true;
              proxy.url = "$https_upstream";
            };
            preread'ldap = {
              listen = {
                ldaps.port = 636;
              };
              ssl.preread.enable = true;
              proxy.url = "$ldap_upstream";
            };
          };
        };
        kerberosConf = let
          system = config.lib.access.systemForService "kerberos";
          inherit (system.exports.services) kerberos;
        in {
          upstreams = let
            addr = mkDefault (config.lib.access.getAddressFor system.name "lan");
            mkKrb5Upstream = portName: {
              enable = mkDefault kerberos.ports.${portName}.enable;
              servers.access = {
                port = mkOptionDefault kerberos.ports.${portName}.port;
                inherit addr;
              };
            };
          in {
            krb5 = mkKrb5Upstream "default";
            kadmin = mkKrb5Upstream "kadmin";
            kpasswd = mkKrb5Upstream "kpasswd";
            kticket5 = mkKrb5Upstream "ticket4";
          };
          servers = let
            mkKrb5Server = tcpPort: udpPort: { name, ... }: {
              listen = {
                tcp = mkIf (tcpPort != null) {
                  enable = mkDefault kerberos.ports.${tcpPort}.enable;
                  port = mkOptionDefault kerberos.ports.${tcpPort}.port;
                };
                udp = mkIf (udpPort != null) {
                  enable = mkDefault kerberos.ports.${udpPort}.enable;
                  port = mkOptionDefault kerberos.ports.${udpPort}.port;
                  extraParameters = [ "udp" ];
                };
              };
              proxy.upstream = name;
            };
          in {
            krb5 = mkKrb5Server "default" "udp";
            kadmin = mkKrb5Server "kadmin" null;
            kpasswd = mkKrb5Server "kpasswd" "kpasswd-udp";
            kticket4 = mkKrb5Server null "ticket4";
          };
        };
        conf.servers = {
          ldap = {
            listen = {
              ldaps.port = mkIf access.preread.enable (mkDefault access.preread.ldapPort);
            };
            proxy.upstream = mkDefault "ldap";
            ssl.cert.copyFromVhost = mkDefault "freeipa";
          };
        };
      in mkMerge [
        conf
        (mkIf access.preread.enable prereadConf)
        (mkIf access.kerberos.enable kerberosConf)
      ];
      streamConfig = let
        inherit (nginx.stream) upstreams;
        preread = ''
          map $ssl_preread_server_name $https_upstream {
            hostnames;
            ${virtualHosts.freeipa.serverName} ${upstreams.freeipa.name};
            ${virtualHosts.freeipa'ca.serverName} ${upstreams.freeipa.name};
            ${nginx.access.ldap.domain} ${upstreams.ldaps_access.name};
            ${nginx.access.ldap.localDomain} ${upstreams.ldaps_access.name};
            ${nginx.access.ldap.intDomain} ${upstreams.ldaps_access.name};
            ${nginx.access.ldap.tailDomain} ${upstreams.ldaps_access.name};
            default ${upstreams.nginx.name};
          }

          map $ssl_preread_server_name $ldap_upstream {
            hostnames;
            ${virtualHosts.freeipa.serverName} ${upstreams.ldaps.name};
            default ${upstreams.ldaps_access.name};
          }
        '';
      in mkIf access.preread.enable preread;
      virtualHosts = let
        name.shortServer = mkDefault "ipa";
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
          serverAliases = [ ldap.intDomain ];
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
          access.kerberos.ports.kadmin
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
