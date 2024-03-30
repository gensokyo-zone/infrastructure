{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib.lib) mapOptionDefaults;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) filter;
  inherit (lib.strings) concatStringsSep concatMapStringsSep escapeShellArgs;
  inherit (config.users) ldap;
  cfg = config.users.ldap.management;
  enabledObjects = filter (object: object.enable) (attrValues cfg.objects);
  smbSyncUsers = filter (user: user.samba.sync.enable) (attrValues cfg.users);
  smbSyncGroups = filter (group: group.samba.sync.enable) (attrValues cfg.groups);
  modifyObjects = filter (object: object.changeType == "modify") enabledObjects;
  addObjects = filter (object: object.changeType == "add") enabledObjects;
  deleteObjects = filter (object: object.changeType == "delete") enabledObjects;
  additions = pkgs.writeText "ldap-management-add.ldap" (
    concatMapStringsSep "\n" (object: object.changeText) addObjects
  );
  # TODO: split up adds and replaces so this can be done without `ldapmodify -c`
  modifications = pkgs.writeText "ldap-management-modify.ldap" (
    concatMapStringsSep "\n" (object: object.changeText) modifyObjects
  );
  deletions = pkgs.writeText "ldap-management-delete.ldap" (
    concatMapStringsSep "\n" (object: object.changeText) deleteObjects
  );
  managementScript = pkgs.writeShellScript "ldap-management-init.sh" ''
    set -eu

    source ${./ldap-common.sh}

    ldapwhoami

    ldapmodify -cf "$MAN_LDAP_ADD" || true

    ldapmodify -c -f "$MAN_LDAP_MODIFY" || true

    ldapmodify -f "$MAN_LDAP_DELETE"
  '';
  syncScript = pkgs.writeShellScript "ldap-management-sync.sh" ''
    set -eu

    source ${./ldap-common.sh}
    source ${./ldap-sync.sh}

    ldapwhoami

    IFS=',' declare -a 'SMB_SYNC_GROUPS=($SMB_SYNC_GROUPS)'
    for SMB_GROUP_CN in "''${SMB_SYNC_GROUPS[@]}"; do
      smbsync_group "$SMB_GROUP_CN"
    done
    IFS=',' declare -a 'SMB_SYNC_USERS=($SMB_SYNC_USERS)'
    for SMB_USER_UID in "''${SMB_SYNC_USERS[@]}"; do
      smbsync_user "$SMB_USER_UID"
    done
  '';
in {
  options.users.ldap.management = with lib.types; {
    enable = mkEnableOption "LDAP object management";
  };
  config.systemd = let
    path = [ config.services.openldap.package pkgs.coreutils ];
    krb5-host = "krb5-host.service";
    ldap-management-init = "ldap-management-init.service";
    ldapEnv = mapOptionDefaults {
      # man 5 ldap.conf
      LDAPBASE = ldap.base;
      LDAPURI = "ldaps://ldap.int.${config.networking.domain}";
    };
    ldapAuth = mkMerge [
      (mkIf config.security.krb5.enable (mapOptionDefaults {
        LDAPSASL_MECH = "GSSAPI";
        LDAPSASL_AUTHCID = "dn:fqdn=${config.networking.fqdn},${ldap.hostDnSuffix}${ldap.base}";
      }))
      (mkIf (config.users.ldap.bind.distinguishedName != "") (mapOptionDefaults {
        LDAPBINDDN = config.users.ldap.bind.distinguishedName;
        LDAPBINDPW_FILE = config.users.ldap.bind.passwordFile;
      }))
    ];
    smbSyncGroupNames = map (group: group.name) smbSyncGroups;
    smbSyncUserNames = map (user: user.uid) smbSyncUsers;
  in mkIf cfg.enable {
    services.ldap-management-init = {
      inherit path;
      wants = [ krb5-host ];
      after = [ krb5-host ];
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [
        "${additions}"
        "${modifications}"
        "${deletions}"
      ];
      environment = mkMerge [
        ldapEnv
        ldapAuth
        (mapOptionDefaults {
          MAN_LDAP_ADD = "${additions}";
          MAN_LDAP_MODIFY = "${modifications}";
          MAN_LDAP_DELETE = "${deletions}";
        })
      ];
      serviceConfig = {
        Type = mkOptionDefault "oneshot";
        ExecStart = [ "${managementScript}" ];
        RemainAfterExit = mkOptionDefault true;
      };
    };
    services.ldap-management-sync = {
      wants = [ krb5-host ];
      requires = [ ldap-management-init ];
      after = [ krb5-host ldap-management-init ];
      path = mkMerge [
        path
        [ pkgs.xxd ]
      ];
      restartTriggers = [
        smbSyncGroupNames
        smbSyncUserNames
      ];
      environment = mkMerge [
        ldapEnv
        ldapAuth
        (mapOptionDefaults {
          LDAP_DNSUFFIX_USER = ldap.userDnSuffix;
          LDAP_DNSUFFIX_GROUP = ldap.groupDnSuffix;
          SMB_SYNC_GROUPS = concatStringsSep "," smbSyncGroupNames;
          SMB_SYNC_USERS = concatStringsSep "," smbSyncUserNames;
        })
      ];
      serviceConfig = {
        Type = mkOptionDefault "oneshot";
        ExecStart = [ "${syncScript}" ];
      };
    };
    timers.ldap-management-sync = {
      wantedBy = [ "timers.target" ];
      timerConfig = mapOptionDefaults {
        OnBootSec = "1m";
        OnUnitInactiveSec = "30m";
      };
    };
  };
}
