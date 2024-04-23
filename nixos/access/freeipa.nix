{
  config,
  meta,
  lib,
  gensokyo-zone,
  ...
}:
let
  inherit (gensokyo-zone.lib) mkAddress6 mapOptionDefaults;
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
  locations = {
    "/" = { config, xvars, ... }: {
      proxy = {
        enable = true;
        url = mkDefault access.proxyPass;
        host = mkDefault virtualHosts.freeipa.serverName;
        ssl.host = mkDefault config.proxy.host;
        headers = {
          rewriteReferer.enable = true;
          set = {
            X-SSL-CERT = "$ssl_client_escaped_cert";
          };
        };
        redirect = {
          enable = true;
          fromHost = config.proxy.host;
          fromScheme = xvars.get.proxy_scheme;
        };
      };
      proxyPass = mkDefault access.proxyPass;
      recommendedProxySettings = false;
    };
  };
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
      # TODO: ssl.preread.enable = mkDefault true;
      access.freeipa = {
        host = mkOptionDefault (config.lib.access.getAddressFor (config.lib.access.systemForService "freeipa").name "lan");
      };
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
          };
          servers = {
            ${nginx.ssl.preread.serverName} = {
              ssl.preread.upstreams = mapOptionDefaults {
                ${virtualHosts.freeipa.serverName} = "freeipa";
                ${virtualHosts.freeipa'ca.serverName} = "freeipa";
                ${nginx.access.ldap.domain} = "ldaps_access";
                ${nginx.access.ldap.localDomain} = "ldaps_access";
                ${nginx.access.ldap.intDomain} = "ldaps_access";
                ${nginx.access.ldap.tailDomain} = "ldaps_access";
              };
            };
            preread'ldap = {
              listen = {
                ldaps.port = access.ldapPort;
              };
              ssl.preread = {
                enable = true;
                upstreams = mapOptionDefaults {
                  ${virtualHosts.freeipa.serverName} = "ldaps";
                  default = "ldaps_access";
                };
              };
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
        conf.upstreams.ldap'access.servers.ldaps.enable = false;
        conf.servers = {
          ldap = {
            listen = {
              ldaps.port = mkIf nginx.ssl.preread.enable (mkDefault access.preread.ldapPort);
            };
            ssl.cert.copyFromVhost = mkDefault "freeipa";
          };
        };
      in mkMerge [
        conf
        (mkIf nginx.ssl.preread.enable prereadConf)
        (mkIf access.kerberos.enable kerberosConf)
      ];
      virtualHosts = let
        name.shortServer = mkDefault "ipa";
      in {
        freeipa = {
          name.shortServer = mkDefault "idp";
          inherit locations extraConfig;
          ssl.force = mkDefault true;
        };
        freeipa'web = {
          ssl = {
            force = mkDefault virtualHosts.freeipa.ssl.force;
            cert.copyFromVhost = "freeipa";
          };
          inherit name locations extraConfig;
        };
        freeipa'ca = {
          name.shortServer = mkDefault "idp-ca";
          locations."/" = mkMerge [
            locations."/"
            {
              proxy.host = virtualHosts.freeipa'ca.serverName;
            }
          ];
          ssl = {
            force = mkDefault virtualHosts.freeipa.ssl.force;
            cert.copyFromVhost = "freeipa";
          };
          inherit extraConfig;
        };
        freeipa'web'local = {
          ssl.cert.copyFromVhost = "freeipa'web";
          local.enable = true;
          inherit name locations;
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
        (mkIf nginx.ssl.preread.enable [
          access.ldapPort
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
