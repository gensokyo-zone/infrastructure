{
  config,
  options,
  lib,
  gensokyo-zone,
  pkgs,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault mapOptionDefaults mapAlmostOptionDefaults;
  inherit (lib.options) mkOption mkEnableOption mkPackageOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkAfter mkForce mkDefault mkOptionDefault;
  inherit (lib.lists) optional elem;
  inherit (lib.strings) toUpper concatStringsSep;
  inherit (gensokyo-zone.lib) unmerged;
  cfg = config.gensokyo-zone.krb5;
  krb5Module = {
    gensokyo-zone,
    nixosConfig,
    nixosOptions,
    config,
    pkgs,
    ...
  }: let
    inherit (gensokyo-zone.lib) unmerged mkBaseDn;
    inherit (nixosConfig.gensokyo-zone) access;
    enabled = {
      krb5 = nixosConfig.security.krb5.enable;
      ipa = config.ipa.enable && nixosConfig.security.ipa.enable;
      sssd = config.sssd.enable && nixosConfig.services.sssd.enable;
    };
  in {
    options = with lib.types; {
      enable = mkEnableOption "kerberos settings";
      domain = mkOption {
        type = str;
        default = gensokyo-zone.lib.domain;
      };
      realm = mkOption {
        type = str;
        default = toUpper config.domain;
      };
      ca = {
        trust = mkEnableOption "trust CA" // {
          default = true;
        };
        pem = mkOption {
          type = path;
        };
      };
      host = mkOption {
        type = str;
        default = config.ipa.host;
      };
      ldap = {
        host = mkOption {
          type = str;
          default = "ldap.${config.domain}";
          example = "ldap.local.${config.domain}";
        };
        urls = mkOption {
          type = listOf str;
          default = [ "ldaps://${config.ldap.host}" ];
        };
        baseDn = mkOption {
          type = str;
          default = mkBaseDn config.domain;
        };
        bind = {
          dn = mkOption {
            type = str;
            default = "uid=peep,cn=sysaccounts,cn=etc,${config.ldap.baseDn}";
          };
          passwordFile = mkOption {
            type = path;
          };
          passwordFileKrb5 = mkOption {
            type = path;
            example = lib.literalExpression "\${pkgs.writeText "ldap.kdb5" ''
              ${config.bind.dn}#{HEX}616e6f6e796d6f7573
            ''}";
          };
          passwordFileSssdEnv = mkOption {
            type = path;
            example = lib.literalExpression "\${pkgs.writeText "ldap.kdb5" ''
              ${"SSSD_AUTHTOK_" + replaceStrings [ "." ] [ "_" ] (toUpper config.domain)}=verysecretpassword
            ''}";
          };
        };
      };
      db = {
        backend = mkOption {
          type = enum [ "kldap" "ipa" ];
          default = "kldap";
        };
      };
      logLevel = mkOption {
        type = str;
        default = "NOTICE";
      };
      authToLocalNames = mkOption {
        type = attrsOf str;
        default = { };
        example = {
          "arc@${config.realm}" = "arc";
        };
      };
      sssd = {
        enable = mkEnableOption "sssd";
        pam.enable = mkEnableOption "PAM";
        backend = mkOption {
          type = enum [ "ipa" "ldap" ];
          default = {
            ipa = "ipa";
            kldap = "ldap";
          }.${config.db.backend};
        };
      };
      ntp = {
        enable = mkEnableOption "ntp" // {
          default = true;
        };
        servers = mkOption {
          type = listOf str;
          example = [ config.ipa.host ];
          default = [ "2.fedora.pool.ntp.org" ];
        };
      };
      nfs = {
        enable = mkEnableOption "nfs";
        package = mkPackageOption pkgs "nfs-utils" { };
        idmapd = {
          localDomain = mkOption {
            type = bool;
            default = enabled.sssd && nixosConfig.services.sssd.services.nss.enable;
          };
          localRealms = mkOption {
            type = listOf str;
            default = [ config.realm ];
          };
          methods = mkOption {
            type = listOf str;
            default = [ "nsswitch" ];
          };
          authToLocalNames = mkOption {
            type = attrsOf str;
            default = config.authToLocalNames;
          };
        };
        debug.enable = mkEnableOption "nfs debug logs";
      };
      ipa = {
        enable = mkEnableOption "IPA";
        httpHost = mkOption {
          type = str;
          default = "freeipa.${config.domain}";
        };
        host = mkOption {
          type = str;
          default = "idp.${config.domain}";
        };
      };
      set = {
        krb5Settings = mkOption {
          type = unmerged.type;
          default = {};
        };
        sssdSettings = mkOption {
          type = unmerged.type;
          default = {};
        };
        ipaSettings = mkOption {
          type = unmerged.type;
          default = {};
        };
        nfsSettings = mkOption {
          type = unmerged.type;
          default = {};
        };
      };
    };
    config = {
      ca.pem = let
        caPem = pkgs.fetchurl {
          name = "${config.ipa.host}.ca.pem";
          url = "https://${config.ipa.httpHost}/ipa/config/ca.crt";
          sha256 = "sha256-PKjnjn1jIq9x4BX8+WGkZfj4HQtmnHqmFSALqggo91o=";
        };
      in mkOptionDefault caPem;
      ldap = {
        urls = mkMerge [
          (mkIf access.local.enable (mkOptionDefault (mkBefore [
            "ldaps://ldap.local.${config.domain}"
          ])))
          (mkIf enabled.ipa (mkOptionDefault (mkBefore [
            "ldaps://${config.ipa.host}"
          ])))
          (mkIf access.tail.enabled (mkOptionDefault (mkAfter [
            "ldap://ldap.tail.${config.domain}"
          ])))
        ];
        bind = let
          inherit (nixosConfig.sops) secrets;
        in mkIf (nixosOptions ? sops.secrets && secrets ? gensokyo-zone-krb5-passwords) {
          passwordFileKrb5 = mkOptionDefault nixosConfig.sops.secrets.gensokyo-zone-krb5-passwords.path;
          passwordFile = mkOptionDefault nixosConfig.sops.secrets.gensokyo-zone-krb5-peep-password.path;
          passwordFileSssdEnv = mkOptionDefault nixosConfig.sops.secrets.gensokyo-zone-sssd-passwords.path;
        };
      };
      db.backend = mkIf enabled.ipa (mkAlmostOptionDefault "ipa");
      nfs = {
        package = mkIf (elem "umich_ldap" config.nfs.idmapd.methods) (mkAlmostOptionDefault pkgs.nfs-utils-ldap);
        idmapd = {
          methods = mkMerge [
            (mkIf (config.nfs.idmapd.authToLocalNames != { }) (
              mkOptionDefault (mkBefore [ "static" ])
            ))
            (mkIf (!enabled.sssd) (
              mkOptionDefault [ "umich_ldap" ]
            ))
          ];
        };
      };
      set = {
        krb5Settings = {
          enable = mkAlmostOptionDefault true;
          gensokyo-zone = {
            enable = mkAlmostOptionDefault true;
            host = mkAlmostOptionDefault config.host;
            canonHost = mkAlmostOptionDefault config.ipa.host;
            domain = mkAlmostOptionDefault config.domain;
            realm = mkAlmostOptionDefault config.realm;
            ca.cert = mkAlmostOptionDefault config.ca.pem;
            db.backend = mkAlmostOptionDefault config.db.backend;
            ldap = {
              baseDn = mkAlmostOptionDefault config.ldap.baseDn;
              urls = mkAlmostOptionDefault config.ldap.urls;
              bind = mapAlmostOptionDefaults {
                dn = config.ldap.bind.dn;
                passwordFile = config.ldap.bind.passwordFileKrb5;
              };
            };
            authToLocalNames = mkAlmostOptionDefault config.authToLocalNames;
          };
        };
        sssdSettings = let
          servers = optional access.local.enable "idp.local.${config.domain}"
            ++ [ "_srv" ];
          backups = mkMerge [
            (mkIf access.tail.enabled (mkAlmostOptionDefault [ "freeipa.tail.${config.domain}" ]))
            (mkIf access.local.enable (mkAlmostOptionDefault [ "freeipa.local.${config.domain}" ]))
          ];
        in mkIf config.sssd.enable {
          enable = mkAlmostOptionDefault true;
          gensokyo-zone = {
            backend = mkAlmostOptionDefault config.sssd.backend;
            krb5.servers = {
              servers = servers ++ [ config.host ];
              inherit backups;
            };
            ipa.servers = {
              servers = servers ++ [ config.ipa.host ];
              inherit backups;
            };
            ldap = {
              bind.passwordFile = mkAlmostOptionDefault config.ldap.bind.passwordFile;
              uris.backups = mkIf access.tail.enabled (mkAlmostOptionDefault (mkAfter [
                "ldaps://ldap.tail.${config.domain}"
              ]));
            };
          };
          environmentFile = mkIf (config.sssd.backend == "ldap") (mkAlmostOptionDefault
            config.ldap.bind.passwordFileSssdEnv
          );
          services = {
            ifp.enable = mkAlmostOptionDefault true;
            pam.enable = mkIf (!config.sssd.pam.enable) (mkDefault false);
          };
        };
        ipaSettings = mkIf config.ipa.enable (mapAlmostOptionDefaults {
          enable = true;
          certificate = config.ca.pem;
          basedn = config.ldap.baseDn;
          domain = config.domain;
          realm = config.realm;
          server = config.ipa.server;
          # TODO: dyndns?
        } // {
          overrideConfigs = mapAlmostOptionDefaults {
            sssd = false;
            krb5 = false;
          };
        });
        nfsSettings = mkIf config.nfs.enable {
          ${if nixosOptions ? services.nfs.settings then "settings" else null} = mkMerge [
            {
              gssd = mapOptionDefaults {
                #use-machine-creds = false;
                avoid-dns = true;
                preferred-realm = config.realm;
              };
            }
            (mkIf config.nfs.debug.enable {
              mountd.debug = mkOptionDefault "all";
              exportfs.debug = mkOptionDefault "all";
              exportd.debug = mkOptionDefault "all";
              general.idmap-verbosity = mkOptionDefault 3;
              idmapd = mapOptionDefaults {
                verbosity = 3;
                idmap-verbosity = 3;
              };
              gssd = mapOptionDefaults {
                verbosity = 3;
                rpc-verbosity = 3;
              };
            })
          ];
          ${if nixosOptions ? services.nfs.settings then null else "extraConfig"} = mkMerge [
            ''
              [gssd]
              #use-machine-creds = false
              avoid-dns = true
              preferred-realm = ${config.realm}
            ''
            (mkIf config.nfs.debug.enable ''
              [mountd]
              debug = all
              [exportfs]
              debug = all
              [exportd]
              debug = all
              [general]
              idmap-verbosity = 3
              [idmapd]
              verbosity = 3
              idmap-verbosity = 3
              [gssd]
              verbosity = 3
              rpc-verbosity = 3
            '')
          ];
          # TODO: move this into a more generic /modules/nixos/nfs that gets configured...
          idmapd.settings = {
            General = mkIf config.nfs.idmapd.localDomain {
              Domain = mkForce config.domain;
              Local-Realms = concatStringsSep "," config.nfs.idmapd.localRealms;
            };
            Translation.Method = mkIf (config.nfs.idmapd.methods != [ "nsswitch" ]) (mkForce (
              concatStringsSep "," config.nfs.idmapd.methods
            ));
            Static = mkIf (config.nfs.idmapd.authToLocalNames != { }) config.nfs.idmapd.authToLocalNames;
            UMICH_SCHEMA = mkIf (elem "umich_ldap" config.nfs.idmapd.methods) (mapOptionDefaults {
              LDAP_server = config.ldap.host;
              LDAP_use_ssl = true;
              LDAP_ca_cert = "/etc/ssl/certs/ca-bundle.crt";
              LDAP_base = config.ldap.baseDn;
              LDAP_people_base = "cn=users,cn=accounts,${config.ldap.baseDn}";
              LDAP_group_base = "cn=groups,cn=accounts,${config.ldap.baseDn}";
              NFSv4_person_objectclass = "posixaccount"; # or "person"?
              NFSv4_name_attr = "krbCanonicalName"; # uid? cn? gecos?
              GSS_principal_attr = "krbPrincipalName";
              NFSv4_group_objectclass = "posixgroup";
              NFSv4_group_attr = "cn";
              #LDAP_use_memberof_for_groups = true;
              #NFSv4_member_attr = "member";
              LDAP_canonicalize_name = false;
            });
          };
        };
      };
    };
  };
in {
  imports = [
    ./access.nix
    ../misc/sssd.nix
    ../misc/ipa.nix
    ../misc/netgroups.nix
    ../../nixos/krb5/genso.nix
    ../../nixos/sssd/genso.nix
  ];

  options.gensokyo-zone.krb5 = mkOption {
    type = lib.types.submoduleWith {
      modules = [krb5Module];
      specialArgs = {
        inherit gensokyo-zone pkgs;
        inherit (gensokyo-zone) inputs;
        nixosConfig = config;
        nixosOptions = options;
      };
    };
    default = { };
  };

  config = {
    nixpkgs = mkIf cfg.enable {
      overlays = [
        gensokyo-zone.overlays.krb5
      ];
    };
    security = {
      krb5 = mkIf cfg.enable (unmerged.merge cfg.set.krb5Settings);
      ipa = mkIf cfg.enable (unmerged.merge cfg.set.ipaSettings);
      pki.certificateFiles = mkIf (cfg.enable && cfg.ca.trust && !cfg.ipa.enable) [
        cfg.ca.pem
      ];
    };
    services.sssd = mkIf cfg.enable (unmerged.merge cfg.set.sssdSettings);
    services.nfs = mkIf cfg.enable (unmerged.merge cfg.set.nfsSettings);
    services.ntp.enable = mkIf (cfg.enable && cfg.ntp.enable) (mkAlmostOptionDefault true);
    networking = {
      timeServers = mkIf (cfg.enable && cfg.ntp.enable) cfg.ntp.servers;
      hosts = let
        inherit (gensokyo-zone.systems) freeipa;
        # TODO: consider hakurei instead...
      in mkIf (cfg.enable && !config.gensokyo-zone.dns.enable or false && config.gensokyo-zone.access.local.enable) {
        ${freeipa.config.access.address6ForNetwork.local} = mkIf config.networking.enableIPv6 (mkBefore [ cfg.host ]);
        ${freeipa.config.access.address4ForNetwork.local} = mkBefore [ cfg.host ];
      };
    };
    environment.etc = {
      "request-key.conf" = mkIf (cfg.enable && cfg.nfs.enable && cfg.sssd.enable) {
        source = let
          nfsidmap = pkgs.writeShellScript "nfsidmap" ''
            export LD_LIBRARY_PATH="$LD_LIBRARY_PATH:${config.system.nssModules.path}"
            exec ${cfg.nfs.package}/bin/nfsidmap "$@"
          '';
        in mkForce (pkgs.writeText "request-key.conf" ''
          create id_resolver * * ${nfsidmap} -t 600 %k %d
        '');
      };
    };
    ${if options ? sops.secrets then "sops" else null}.secrets = let
      sopsFile = mkDefault ../secrets/krb5.yaml;
    in mkIf cfg.enable {
      gensokyo-zone-krb5-passwords = mkIf (cfg.db.backend == "kldap") {
        inherit sopsFile;
      };
      gensokyo-zone-krb5-peep-password = mkIf (cfg.sssd.backend == "ldap") {
        inherit sopsFile;
      };
      gensokyo-zone-sssd-passwords = mkIf (cfg.sssd.backend == "ldap") {
        inherit sopsFile;
      };
    };
    lib.gensokyo-zone.krb5 = {
      inherit cfg krb5Module;
    };
  };
}
