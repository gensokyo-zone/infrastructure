{ inputs, pkgs, config, lib, ... }: let
  inherit (inputs.self.lib.lib) mkBaseDn;
  inherit (lib.modules) mkIf mkBefore mkDefault mkOptionDefault;
  inherit (lib.strings) toUpper;
  inherit (config.networking) domain;
  cfg = config.security.ipa;
  baseDn = mkBaseDn domain;
  caPem = pkgs.fetchurl {
    name = "idp.${domain}.ca.pem";
    url = "https://freeipa.${domain}/ipa/config/ca.crt";
    sha256 = "sha256-PKjnjn1jIq9x4BX8+WGkZfj4HQtmnHqmFSALqggo91o=";
  };
in {
  # NOTE: requires manual post-install setup...
  # :; kinit admin
  # :; ipa-join --hostname=${config.networking.fqdn} -k /tmp/krb5.keytab -s idp.${domain}
  # then to authorize it for a specific service...
  # :; ipa-getkeytab -k /tmp/krb5.keytab -s idp.${domain} -p ${serviceName}/idp.${domain}@${toUpper domain}
  # once the sops secret has been updated with keytab...
  # :; systemctl restart sssd
  config = {
    users.ldap = {
      base = mkDefault baseDn;
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
      sysAccountDnSuffix = mkDefault "cn=sysaccounts,cn=etc,";
      domainDnSuffix = mkDefault "cn=ad,cn=etc,";
    };
    security.ipa = {
      enable = mkDefault true;
      certificate = mkDefault caPem;
      basedn = mkDefault baseDn;
      chromiumSupport = mkDefault false;
      domain = mkDefault domain;
      realm = mkDefault (toUpper domain);
      server = mkDefault "idp.${domain}";
      ifpAllowedUids = [
        "root"
      ] ++ config.users.groups.wheel.members;
      dyndns.enable = mkDefault false;
    };
    networking.hosts = mkIf cfg.enable {
      "10.1.1.46" = mkBefore [ "idp.${domain}" ];
    };
    sops.secrets = {
      krb5-keytab = mkIf cfg.enable {
        mode = "0400";
        path = "/etc/krb5.keytab";
      };
    };
    systemd.services.krb5-host = let
      krb5-host = pkgs.writeShellScript "krb5-host" ''
        set -eu

        kinit -k host/${config.networking.fqdn}
      '';
    in mkIf cfg.enable {
      path = [ config.security.krb5.package ];
      serviceConfig = {
        Type = mkOptionDefault "oneshot";
        ExecStart = [ "${krb5-host}" ];
      };
    };
  };
}
