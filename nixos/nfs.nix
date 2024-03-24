{
  inputs,
  config,
  lib,
  ...
}: let
  inherit (inputs.self.lib.lib) mkBaseDn;
  inherit (lib.modules) mkIf mkForce mkDefault;
  inherit (lib.lists) optional optionals;
  inherit (lib.strings) toUpper concatStringsSep;
  inherit (config.networking.access) cidrForNetwork;
  cfg = config.services.nfs;
  inherit (cfg.export) flagSets;
  inherit (config.networking) domain;
  enableLdap = false;
  baseDn = mkBaseDn domain;
in {
  config.services.nfs = {
    server = {
      enable = mkDefault true;
      statdPort = mkDefault 4000;
      lockdPort = mkDefault 4001;
      mountdPort = mkDefault 4002;
    };
    export = {
      flagSets = {
        common = [
          "no_subtree_check"
          "anonuid=${toString config.users.users.guest.uid}"
          "anongid=${toString config.users.groups.${config.users.users.guest.group}.gid}"
        ];
        sec = [
          "sec=${concatStringsSep ":" [ "krb5i" "krb5" "krb5p" ]}"
        ];
        seclocal = [
          "sec=${concatStringsSep ":" [ "krb5" ]}"
        ];
        secip = [
          "sec=${concatStringsSep ":" [ "krb5i" "krb5p" ]}"
        ];
        secanon = [
          "sec=${concatStringsSep ":" [ "krb5i" "krb5" "krb5p" "sys" ]}"
        ];
        anon_ro = [
          "sec=sys"
          "all_squash"
          "ro"
        ];
        # client machines
        clientGroups = [
          "@peeps"
          "@infra"
        ];
        trustedClients = [
          "@trusted"
        ];
        tailClients = optionals config.services.tailscale.enable cidrForNetwork.tail.all;
        localClients = cidrForNetwork.allLan.all ++ flagSets.tailClients;
        allClients = flagSets.clientGroups ++ flagSets.trustedClients ++ flagSets.localClients;
      };
      root = {
        path = "/srv/fs";
        clients = {
          trusted = {
            machine = flagSets.trustedClients;
            flags = flagSets.secip ++ [ "rw" ];
          };
        };
      };
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
}
