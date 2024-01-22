{
  config,
  lib,
  access,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.lists) any;
  inherit (lib.strings) hasInfix;
  inherit (config.services) samba samba-wsdd;
  system = access.systemFor "tei";
  inherit (system.services) kanidm;
  enableLdap = false;
  hasIpv4 = any (hasInfix ".") config.systemd.network.networks.eth0.address or [ ];
in {
  services.samba = {
    openFirewall = mkDefault true;
    enable = mkDefault true;
    enableWinbindd = mkDefault false;
    enableNmbd = mkDefault hasIpv4;
    securityType = mkDefault "user";
    package = mkIf enableLdap (mkDefault (pkgs.samba.override {
      enableLDAP = true;
    }));
    extraConfig = mkMerge [
      ''
        workgroup = GENSOKYO
        local master = no
        preferred master = no
        winbind offline logon = yes
        winbind scan trusted domains = no
        winbind use default domain = yes
        domain master = no
        valid users = nobody, arc, kat, @nfs
        map to guest = Bad User
        guest account = nobody
      ''
      (mkIf hasIpv4 ''
        remote announce = 10.1.1.255/GENSOKYO
      '')
      (mkIf enableLdap ''
        idmap config * : backend = ldap
        idmap config * : range = 1000 - 2000
        idmap config * : read only = yes
        idmap config * : ldap_url = ldaps://ldap.local.${config.networking.domain}
        idmap config * : ldap_base_dn = ${kanidm.server.ldap.baseDn}
        passdb backend = ldapsam:"ldaps://ldap.local.${config.networking.domain}"
        ldap ssl = off
        ldap admin dn = name=anonymous,${kanidm.server.ldap.baseDn}
        ldap suffix = ${kanidm.server.ldap.baseDn}
        ntlm auth = disabled
        encrypt passwords = no
      '')
      (mkIf (!enableLdap) ''
        passdb backend = smbpasswd:${config.sops.secrets.smbpasswd.path}
        idmap config * : backend = nss
        idmap config * : range = 1000 - 2000
        idmap config * : read only = yes
      '')
    ];
  };

  systemd.services.samba-smbd = mkIf samba.enable {
    serviceConfig.ExecStartPre = let
      ldap-pass = pkgs.writeShellScript "smb-ldap-pass" ''
        ${samba.package}/bin/smbpasswd -c /etc/samba/smb.conf -w anonymous
      '';
    in mkIf enableLdap [
      "${ldap-pass}"
    ];
  };

  services.samba-wsdd = mkIf samba.enable {
    enable = mkDefault true;
    openFirewall = mkDefault true;
    hostname = mkDefault config.networking.hostName;
  };

  networking.firewall.interfaces.local = {
    allowedTCPPorts = mkMerge [
      (mkIf samba.enable [ 139 445 ])
      (mkIf samba-wsdd.enable [ 5357 ])
    ];
    allowedUDPPorts = mkMerge [
      (mkIf samba.enable [ 137 138 ])
      (mkIf samba-wsdd.enable [ 3702 ])
    ];
  };

  sops.secrets.smbpasswd = {
    sopsFile = mkDefault ./secrets/samba.yaml;
    #path = "/var/lib/samba/private/smbpasswd";
  };
}
