{ inputs, pkgs, config, access, lib, ... }: let
  inherit (inputs.self.lib.lib) mkAlmostOptionDefault mapAlmostOptionDefaults;
  inherit (lib.modules) mkIf mkMerge mkBefore mkDefault mkOptionDefault;
  inherit (lib.strings) replaceStrings;
  inherit (config.security) ipa;
  cfg = config.security.krb5;
  enabled = cfg.enable || ipa.enable;
  domain = cfg.gensokyo-zone.domain;
in {
  config = {
    security.krb5 = {
      enable = mkIf (!ipa.enable) (mkDefault true);
      settings = {
        libdefaults = mapAlmostOptionDefaults {
          dns_lookup_kdc = false;
          rdns = false;
        };
      };
      gensokyo-zone = let
        toLdap = replaceStrings [ "idp." ] [ "ldap." ];
        lanName = access.getHostnameFor "freeipa" "lan";
        localName = access.getHostnameFor "freeipa" "local";
        ldapLan = toLdap lanName;
        ldapLocal = toLdap localName;
      in {
        enable = mkDefault true;
        host = mkAlmostOptionDefault lanName;
        ldap = {
          urls = mkMerge [
            (mkOptionDefault (mkBefore [ "ldaps://${ldapLan}" ]))
            (mkIf (ldapLan != ldapLocal) (mkOptionDefault (mkBefore [ "ldaps://${ldapLan}" ])))
          ];
          bind.passwordFile = mkIf (cfg.gensokyo-zone.db.backend == "kldap") config.sops.secrets.gensokyo-zone-krb5-passwords.path;
        };
      };
    };
    users.ldap = {
      base = mkDefault cfg.gensokyo-zone.ldap.baseDn;
      server = mkDefault "ldaps://ldap.local.${domain}";
      samba.domainSID = mkDefault "S-1-5-21-1535650373-1457993706-2355445124";
      #samba.domainSID = mkDefault "S-1-5-21-208293719-3143191303-229982100"; # HAKUREI
      userDnSuffix = mkDefault "cn=users,cn=accounts,";
      groupDnSuffix = mkDefault "cn=groups,cn=accounts,";
      permissionDnSuffix = mkDefault "cn=permissions,cn=pbac,";
      privilegeDnSuffix = mkDefault "cn=privileges,cn=pbac,";
      roleDnSuffix = mkDefault "cn=roles,cn=accounts,";
      serviceDnSuffix = mkDefault "cn=services,cn=accounts,";
      hostDnSuffix = mkDefault "cn=computers,cn=accounts,";
      hostGroupDnSuffix = mkDefault "cn=hostgroups,cn=accounts,";
      idViewDnSuffix = mkDefault "cn=views,cn=accounts,";
      sysAccountDnSuffix = mkDefault "cn=sysaccounts,cn=etc,";
      domainDnSuffix = mkDefault "cn=ad,cn=etc,";
    };
    networking.timeServers = [ "2.fedora.pool.ntp.org" ];
    security.ipa = {
      chromiumSupport = mkDefault false;
    };
    services.sssd = {
      domains.${domain}.settings = {
        enumerate = true;
      };
    };

    systemd.services.krb5-host = let
      krb5-host = pkgs.writeShellScript "krb5-host" ''
        set -eu

        kinit -k host/${config.networking.fqdn}
      '';
    in mkIf enabled {
      path = [ config.security.krb5.package ];
      serviceConfig = {
        Type = mkOptionDefault "oneshot";
        ExecStart = [ "${krb5-host}" ];
      };
    };

    sops.secrets = let
      sopsFile = mkDefault ./secrets/krb5.yaml;
    in mkIf enabled {
      krb5-keytab = {
        mode = "0400";
        path = "/etc/krb5.keytab";
      };
      gensokyo-zone-krb5-passwords = mkIf (cfg.gensokyo-zone.db.backend == "kldap") {
        inherit sopsFile;
      };
    };
  };
}
