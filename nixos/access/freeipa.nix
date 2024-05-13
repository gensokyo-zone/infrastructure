{
  config,
  meta,
  access,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mapOptionDefaults;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (config.services) tailscale;
  inherit (config.services) nginx;
  inherit (nginx) virtualHosts;
  cfg = nginx.access.freeipa;
  inherit (nginx.access) ldap;
  extraConfig = ''
    ssl_verify_client optional_no_ca;
  '';
  locations = {
    "/" = {
      config,
      xvars,
      ...
    }: {
      proxy = {
        enable = true;
        upstream = "freeipa";
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
    };
  };
  locations'cockpit = {
    "/" = {xvars, ...}: {
      proxy = {
        enable = true;
        host = xvars.get.host;
      };
    };
    "/cockpit/socket" = {
      proxy = {
        enable = true;
        websocket.enable = true;
      };
    };
  };
  ldapsPort = 636;
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.access.ldap
  ];

  options.services.nginx.access.freeipa = with lib.types; {
    preread = {
      ldapPort = mkOption {
        type = port;
        default = 637;
      };
    };
    kerberos = {
      enable =
        mkEnableOption "proxy kerberos"
        // {
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
  };
  config = {
    services.nginx = {
      # TODO: ssl.preread.enable = mkDefault true;
      upstreams' = {
        freeipa = {config, ...}: {
          ssl.host = mkDefault (access.systemFor config.servers.access.accessService.system).access.fqdn;
          host = mkDefault config.ssl.host;
          servers.access = {
            accessService = {
              name = "freeipa";
            };
          };
        };
        freeipa'cockpit = {upstream, ...}: {
          servers.access = {
            accessService = {
              inherit (nginx.upstreams'.freeipa.servers.access.accessService) system;
              name = "cockpit";
            };
          };
        };
      };
      stream = let
        prereadConf = {
          upstreams = {
            freeipa = let
              inherit (nginx.upstreams') freeipa;
            in {
              ssl.host = mkDefault freeipa.ssl.host;
              servers.access.accessService = {
                inherit (freeipa.servers.access.accessService) system name id port;
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
                ldaps.port = ldapsPort;
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
          system = access.systemFor nginx.stream.upstreams.krb5.servers.access.accessService.system;
          inherit (system.exports.services) kerberos;
        in {
          upstreams = let
            mkKrb5Upstream = port: {config, ...}: {
              enable = mkDefault config.servers.access.enable;
              servers.access = {
                accessService = {
                  name = "kerberos";
                  inherit port;
                };
              };
            };
          in {
            krb5 = mkKrb5Upstream "default";
            kadmin = mkKrb5Upstream "kadmin";
            kpasswd = mkKrb5Upstream "kpasswd";
            kticket4 = mkKrb5Upstream "ticket4";
          };
          servers = let
            mkKrb5Server = tcpPort: udpPort: {name, ...}: {
              enable = mkDefault nginx.stream.upstreams.${name}.enable;
              listen = {
                tcp = mkIf (tcpPort != null) {
                  enable = mkDefault kerberos.ports.${tcpPort}.enable;
                  port = mkOptionDefault kerberos.ports.${tcpPort}.port;
                };
                udp = mkIf (udpPort != null) {
                  enable = mkDefault kerberos.ports.${udpPort}.enable;
                  port = mkOptionDefault kerberos.ports.${udpPort}.port;
                  extraParameters = ["udp"];
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
              ldaps.port = mkIf nginx.ssl.preread.enable (mkDefault cfg.preread.ldapPort);
            };
            ssl.cert.copyFromVhost = mkDefault "freeipa";
          };
        };
      in
        mkMerge [
          conf
          (mkIf nginx.ssl.preread.enable prereadConf)
          (mkIf cfg.kerberos.enable kerberosConf)
        ];
      virtualHosts = let
        name.shortServer = mkDefault "ipa";
        name'cockpit.shortServer = mkDefault "ipa-cock";
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
            ({
              config,
              virtualHost,
              ...
            }: {
              proxy.ssl.host = virtualHost.serverName;
              proxy.host = config.proxy.ssl.host;
            })
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
          inherit name locations extraConfig;
        };
        freeipa'cockpit = {
          name = name'cockpit;
          vouch.enable = mkDefault true;
          ssl = {
            force = mkDefault true;
            cert.copyFromVhost = "freeipa'web";
          };
          proxy.upstream = "freeipa'cockpit";
          locations = locations'cockpit;
        };
        freeipa'cockpit'local = {
          name = name'cockpit;
          ssl = {
            force = mkDefault true;
            cert.copyFromVhost = "freeipa'cockpit";
          };
          proxy.copyFromVhost = "freeipa'cockpit";
          local.enable = true;
          locations = locations'cockpit;
        };
        freeipa'ldap = {
          serverName = mkDefault ldap.domain;
          ssl.cert.copyFromVhost = "freeipa";
          globalRedirect = virtualHosts.freeipa'web.serverName;
        };
        freeipa'ldap'local = {
          serverName = mkDefault ldap.localDomain;
          serverAliases = [ldap.intDomain];
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

    networking.firewall = let
      inherit (nginx.stream.servers) krb5 kadmin kpasswd kticket4;
    in {
      allowedTCPPorts = mkMerge [
        (mkIf cfg.kerberos.enable (map (
          server:
            mkIf (server.enable && server.listen.tcp.enable) server.listen.tcp.port
        ) [krb5 kticket4 kpasswd kadmin]))
        (mkIf nginx.ssl.preread.enable [
          ldapsPort
        ])
      ];
      allowedUDPPorts = mkIf cfg.kerberos.enable (map (
        server:
          mkIf (server.enable && server.listen.udp.enable) server.listen.udp.port
      ) [krb5 kticket4 kpasswd]);
    };
  };
}
