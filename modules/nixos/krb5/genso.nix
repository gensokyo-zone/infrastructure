{
  gensokyo-zone,
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mkBaseDn mapDefaults mkAlmostOptionDefault mapOptionDefaults domain;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault mkForce;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.strings) toUpper concatStringsSep concatStrings;
  inherit (config.security) krb5 ipa;
  cfg = krb5.gensokyo-zone;
  enabled = krb5.enable || ipa.enable;
  subsection = attrs: "{\n" + concatStrings (mapAttrsToList (key: value: "  ${key} = ${value}\n") attrs) + "}";
in {
  options.security.krb5.gensokyo-zone = with lib.types; {
    enable = mkEnableOption "realm";
    host = mkOption {
      type = str;
      default = cfg.canonHost;
    };
    canonHost = mkOption {
      type = str;
      default = "idp.${cfg.domain}";
    };
    domain = mkOption {
      type = str;
      default = domain;
    };
    realm = mkOption {
      type = str;
      default = toUpper cfg.domain;
    };
    ca.cert = mkOption {
      type = path;
    };
    ldap = {
      baseDn = mkOption {
        type = str;
        default = mkBaseDn cfg.domain;
      };
      bind = {
        dn = mkOption {
          type = str;
          default = "uid=peep,cn=sysaccounts,cn=etc,${cfg.ldap.base}";
        };
        passwordFile = mkOption {
          type = nullOr str;
          default = null;
        };
      };
      urls = mkOption {
        type = listOf str;
      };
    };
    db.backend = mkOption {
      type = enum ["kldap" "ipa"];
      default = "kldap";
    };
    authToLocalNames = mkOption {
      type = attrsOf str;
      default = {};
    };
  };
  config = {
    security.krb5 = {
      package = let
        krb5-ldap = pkgs.krb5.override {
          withLdap = true;
        };
      in
        mkIf (cfg.enable && cfg.db.backend == "kldap") (mkDefault pkgs.krb5-ldap or krb5-ldap);
      settings = mkIf cfg.enable {
        dbmodules = {
          genso-kldap = mkIf (cfg.db.backend == "kldap") (mapDefaults {
              db_library = "kldap";
              ldap_servers = concatStringsSep " " cfg.ldap.urls;
              ldap_kdc_dn = cfg.ldap.bind.dn;
              ldap_kerberos_container_dn = cfg.ldap.baseDn;
            }
            // {
              ldap_service_password_file = mkIf (cfg.ldap.bind.passwordFile != null) (mkDefault cfg.ldap.bind.passwordFile);
            });
          genso-ipa = mkIf (cfg.db.backend == "ipa") (mapDefaults {
            db_library = "${ipa.package}/lib/krb5/plugins/kdb/ipadb.so";
          });
          ${cfg.realm} = mkIf ipa.enable (mkForce {});
        };
        realms.${cfg.realm} =
          mapDefaults {
            kdc = "${cfg.host}:88";
            master_kdc = "${cfg.host}:88";
            admin_server = "${cfg.host}:749";
            default_domain = cfg.domain;
            pkinit_anchors = ["FILE:${cfg.ca.cert}"];
          }
          // {
            database_module = mkOptionDefault "genso-${cfg.db.backend}";
            auth_to_local_names = mkIf (cfg.authToLocalNames != {}) (mkDefault (subsection cfg.authToLocalNames));
          };
        domain_realm = mapOptionDefaults {
          ${cfg.domain} = cfg.realm;
          ".${cfg.domain}" = cfg.realm;
        };
        libdefaults = mapOptionDefaults {
          default_realm = cfg.realm;
          dns_lookup_realm = false;
          dns_lookup_kdc = true;
          rdns = false;
          ticket_lifetime = "24h";
          forwardable = true;
          udp_preference_limit = 0;
          ignore_acceptor_hostname = true;
        };
      };
      gensokyo-zone = {
        ca.cert = let
          caPem = pkgs.fetchurl {
            name = "${cfg.canonHost}.ca.pem";
            url = "https://ipa.${cfg.domain}/ipa/config/ca.crt";
            sha256 = "sha256-PKjnjn1jIq9x4BX8+WGkZfj4HQtmnHqmFSALqggo91o=";
          };
        in
          mkOptionDefault caPem;
        db.backend = mkIf ipa.enable (mkAlmostOptionDefault "ipa");
        ldap.urls = mkOptionDefault [
          "ldaps://ldap.${cfg.domain}"
          "ldaps://${cfg.canonHost}"
        ];
      };
    };
    networking.timeServers = mkIf (cfg.enable && enabled) ["2.fedora.pool.ntp.org"];
    security.ipa = mkIf cfg.enable {
      certificate = mkDefault cfg.ca.cert;
      basedn = mkDefault cfg.ldap.baseDn;
      domain = mkDefault cfg.domain;
      realm = mkDefault cfg.realm;
      server = mkDefault cfg.canonHost;
      ifpAllowedUids =
        [
          "root"
        ]
        ++ config.users.groups.wheel.members;
      dyndns.enable = mkDefault false;
    };
  };
}
