{
  inputs,
  config,
  lib,
  ...
}: let
  inherit (inputs.self.lib.lib) mkBaseDn;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.lists) any;
  inherit (lib.strings) toUpper hasInfix;
  cfg = config.services.samba;
  inherit (config.networking) domain;
  hasIpv4 = any (hasInfix ".") config.systemd.network.networks.eth0.address or [];
in {
  services.samba = {
    enable = mkDefault true;
    enableWinbindd = mkDefault false;
    enableNmbd = mkDefault hasIpv4;
    securityType = mkDefault "user";
    ldap = {
      enable = mkDefault true;
      url = mkDefault "ldaps://ldap.int.${domain}";
      baseDn = mkDefault (mkBaseDn domain);
      adminDn = mkDefault "uid=samba,cn=sysaccounts,cn=etc,${cfg.ldap.baseDn}";
      adminPasswordPath = mkIf cfg.ldap.enable (
        mkDefault config.sops.secrets.smb-ldap-password.path
      );
      passdb = {
        # XXX: broken backend :<
        #backend = mkIf config.security.ipa.enable (mkDefault "ipasam");
      };
      idmap = {
        enable = mkIf config.services.sssd.enable (mkDefault false);
        domain = mkDefault cfg.settings.workgroup;
      };
    };
    kerberos = mkIf (config.security.krb5.enable || config.security.ipa.enable) {
      enable = true;
      realm = toUpper domain;
    };
    usershare = {
      group = mkDefault "peeps";
    };
    guest = {
      enable = mkDefault true;
      user = mkDefault "guest";
    };
    passdb.smbpasswd.path = mkIf (!cfg.ldap.enable || !cfg.ldap.passdb.enable) (
      mkDefault config.sops.secrets.smbpasswd.path
    );
    settings = mkMerge [ {
      workgroup = "GENSOKYO";
      "local master" = false;
      "preferred master" = false;
      "winbind offline logon" = true;
      "winbind scan trusted domains" = false;
      "winbind use default domain" = true;
      "domain master" = false;
      "domain logons" = true;
      "remote announce" = mkIf hasIpv4 [
        "10.1.1.255/${cfg.settings.workgroup}"
      ];
    } (mkIf cfg.ldap.enable {
      "ldapsam:trusted" = true;
      "ldapsam:editposix" = false;
      "ldap user suffix" = "cn=users,cn=accounts";
      "ldap group suffix" = "cn=groups,cn=accounts";
    }) ];
    idmap.domains = {
      nss = mkIf (!cfg.ldap.enable || !cfg.ldap.idmap.enable) {
        backend = "nss";
        domain = "*";
        range.min = 8000;
        #range.max = 8256;
      };
      ldap = mkIf (cfg.ldap.enable && cfg.ldap.idmap.enable) {
        range.min = 8000;
        #range.min = 8256;
      };
    };
  };

  services.samba-wsdd = {
    enable = mkIf cfg.enable (mkDefault true);
    hostname = mkDefault config.networking.hostName;
  };

  sops.secrets = {
    smbpasswd = mkIf (!cfg.ldap.enable || !cfg.ldap.passdb.enable) {
      sopsFile = mkDefault ./secrets/samba.yaml;
      #path = "/var/lib/samba/private/smbpasswd";
    };
    smb-ldap-password = mkIf cfg.ldap.enable {
      sopsFile = mkDefault ./secrets/samba.yaml;
    };
  };
}
