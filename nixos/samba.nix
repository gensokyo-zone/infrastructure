{
  config,
  systemConfig,
  access,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mkBaseDn;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.strings) toUpper removeSuffix;
  cfg = config.services.samba;
  inherit (config.networking) domain;
  inherit (config.users) ldap;
  debugLogging = false;
  ldapReadOnly = true;
in {
  services.samba = {
    enable = mkDefault true;
    winbindd.enable = mkDefault true;
    nmbd.enable = mkDefault true;
    # TODO: security = "ADS"? kerberos..!
    settings.global.security = mkDefault "user";
    domain = {
      name = "GENSOKYO";
      netbiosName = "reisen";
      netbiosHostAddresses = {
        ${cfg.domain.netbiosName'} = mkIf systemConfig.network.networks.local.enable or false [
          systemConfig.network.networks.local.address4
          systemConfig.network.networks.local.address6
        ];
      };
    };
    ldap = {
      enable = mkDefault true;
      url = mkDefault "ldaps://ldap.int.${domain}";
      baseDn = mkDefault (mkBaseDn domain);
      adminDn = mkDefault "uid=samba,${ldap.sysAccountDnSuffix}${cfg.ldap.baseDn}";
      adminPasswordPath = mkIf cfg.ldap.enable (
        mkDefault config.sops.secrets.smb-ldap-password.path
      );
      passdb = {
        # XXX: broken backend :<
        #backend = mkIf config.security.ipa.enable (mkDefault "ipasam");
      };
      idmap = {
        #enable = mkIf config.services.sssd.enable (mkDefault false);
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
    settings' = mkMerge [
      {
        "local master" = true;
        "preferred master" = true;
        "winbind offline logon" = true;
        "winbind scan trusted domains" = false;
        "winbind use default domain" = true;
        "domain master" = true;
        "server role" = "classic primary domain controller";
        "domain logons" = true;
        "remote announce" = [
          "10.1.1.255/${cfg.domain.name}"
        ];
        "additional dns hostnames" = mkMerge [
          [
            config.networking.fqdn
            "smb.${domain}"
          ]
          (mkIf systemConfig.network.networks.local.enable or false [
            "smb.local.${domain}"
            access.hostnameForNetwork.local
          ])
          (mkIf systemConfig.network.networks.int.enable or false [
            "smb.int.${domain}"
            access.hostnameForNetwork.int
          ])
          (mkIf config.services.tailscale.enable [
            "smb.tail.${domain}"
            access.hostnameForNetwork.tail
          ])
        ];
      }
      (mkIf cfg.ldap.enable {
        "ldapsam:trusted" = true;
        "ldapsam:editposix" = false;
        "ldap user suffix" = removeSuffix "," ldap.userDnSuffix;
        "ldap group suffix" = removeSuffix "," ldap.groupDnSuffix;
        "ldap machine suffix" = removeSuffix "," ldap.hostDnSuffix;
        "ldap idmap suffix" = removeSuffix "," ldap.idViewDnSuffix;
        "ldap server require strong auth" = "allow_sasl_over_tls";
        # TODO: ldap delete dn?
        # TODO: username map script?
      })
      (mkIf debugLogging {
        "ldap debug level" = 1;
        #"ldap debug threshold" = 3; # 4? 5?
        logging = "systemd";
        "log level" = [
          "4"
          #"passdb:8"
          #"auth:8"
          #"idmap:8"
          #"winbind:6"
          #"dns:8"
        ];
      })
    ];
    idmap.domains = {
      nss = mkIf (!cfg.ldap.enable || !cfg.ldap.idmap.enable) {
        backend = "nss";
        domain = "*";
        range.min = 8000;
        #range.max = 9000;
        range.max = 65535;
      };
      ldap = mkIf (cfg.ldap.enable && cfg.ldap.idmap.enable) {
        range.min = 8000;
        #range.max = 9000;
        range.max = 65535;
        readOnly = ldapReadOnly;
      };
    };
  };

  services.samba-wsdd = {
    enable = mkIf cfg.enable (mkDefault true);
    interface = mkDefault config.systemd.network.networks._00-local.name;
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
