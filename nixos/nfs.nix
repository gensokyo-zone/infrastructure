{
  inputs,
  config,
  lib,
  ...
}: let
  inherit (inputs.self.lib.lib) mkBaseDn;
  inherit (lib.modules) mkIf mkForce mkDefault;
  inherit (lib.lists) optional;
  inherit (lib.strings) toUpper concatStringsSep concatMapStringsSep splitString;
  cfg = config.services.nfs;
  inherit (config.networking) domain;
  openPorts = [
    (mkIf cfg.server.enable 2049)
    (mkIf config.services.rpcbind.enable 111)
    (mkIf (cfg.server.statdPort != null) cfg.server.statdPort)
    (mkIf (cfg.server.lockdPort != null) cfg.server.lockdPort)
    (mkIf (cfg.server.mountdPort != null) cfg.server.mountdPort)
  ];
  enableLdap = false;
  baseDn = mkBaseDn domain;
in {
  services.nfs = {
    server = {
      enable = mkDefault true;
      statdPort = mkDefault 4000;
      lockdPort = mkDefault 4001;
      mountdPort = mkDefault 4002;
    };
    idmapd.settings = {
      General = {
        Domain = mkForce domain;
        Local-Realms = concatStringsSep "," [
          (toUpper domain)
          #(toString config.networking.fqdn)
        ];
      };
      Translation.Method = mkForce (concatStringsSep "," (
        [ "static" ]
        ++ optional enableLdap "umich_ldap"
        ++ [ "nsswitch" ]
      ));
      Static = {
      };
      UMICH_SCHEMA = mkIf enableLdap {
        LDAP_server = "ldap.local.${domain}";
        LDAP_use_ssl = true;
        LDAP_ca_cert = "/etc/ssl/certs/ca-bundle.crt";
        LDAP_base = baseDn;
        LDAP_people_base = "cn=users,cn=accounts,${baseDn}";
        LDAP_group_base = "cn=groups,cn=accounts,${baseDn}";
        GSS_principal_attr = "krbPrincipalName";
        NFSv4_person_objectclass = "posixaccount"; # or "person"?
        NFSv4_group_objectclass = "posixgroup";
        NFSv4_name_attr = "krbCanonicalName"; # uid? cn? gecos?
        NFSv4_group_attr = "cn";
        NFSv4_uid_attr = "gidnumber";
        NFSv4_gid_attr = "uidnumber";
        #LDAP_use_memberof_for_groups = true;
        LDAP_canonicalize_name = false;
      };
    };
  };
  networking.firewall.interfaces.local = {
    allowedTCPPorts = openPorts;
    allowedUDPPorts = openPorts;
  };
}
