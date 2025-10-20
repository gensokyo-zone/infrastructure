{
  config,
  gensokyo-zone,
  lib,
  pkgs,
  ...
}: let
  inherit (gensokyo-zone.lib) mapOptionDefaults;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) filter;
  inherit (lib.strings) concatStringsSep concatMapStringsSep;
  inherit (config.users) ldap;
  cfg = config.users.ldap.management;
  ldap'lib = config.lib.ldap;
  enabledObjects = filter (object: object.enable) (attrValues cfg.objects);
  sysAccounts = filter (acc: acc.enable) (attrValues cfg.sysAccounts);
  sysAccountPasswordFiles = concatMapStringsSep "," (acc: "${acc.uid}=${toString acc.passwordFile}") sysAccounts;
  privileges = filter (priv: priv.enable) (attrValues cfg.privileges);
  privilegePermissions = concatMapStringsSep "," (priv: "${priv.cn}=${concatStringsSep "." priv.permissions}") privileges;
  roles = filter (role: role.enable) (attrValues cfg.roles);
  rolePrivileges = concatMapStringsSep "," (role: "${role.cn}=${concatStringsSep "." role.privileges}") roles;
  roleMembers = concatMapStringsSep "+" (role: "${role.cn}=${concatMapStringsSep "%" ldap'lib.withBaseDn role.members}") roles;
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
  sysaccountScript = pkgs.writeShellScript "ldap-management-sysaccounts.sh" ''
    set -eu

    source ${./ldap-common.sh}
    source ${./ldap-sync.sh}

    IFS=',' declare -a 'SYSACCOUNT_PASSWORD_FILES=($SYSACCOUNT_PASSWORD_FILES)'
    for SYSACCOUNT_PASSWORD_FILE in "''${SYSACCOUNT_PASSWORD_FILES[@]}"; do
      SYSACCOUNT_UID=''${SYSACCOUNT_PASSWORD_FILE%%=*}
      SYSACCOUNT_PASSWORD_PATH=''${SYSACCOUNT_PASSWORD_FILE#*=}
      if [[ -n $SYSACCOUNT_PASSWORD_PATH ]]; then
        sysaccount_password "$SYSACCOUNT_UID" "$SYSACCOUNT_PASSWORD_PATH"
      fi
    done
  '';
  privilegeScript = pkgs.writeShellScript "ldap-management-privileges.sh" ''
    set -eu

    source ${./ldap-common.sh}
    source ${./ldap-sync.sh}

    IFS=',' declare -a 'PRIVILEGE_PERMISSIONS=($PRIVILEGE_PERMISSIONS)'
    for PRIVILEGE_PERMISSION in "''${PRIVILEGE_PERMISSIONS[@]}"; do
      PRIVILEGE_CN=''${PRIVILEGE_PERMISSION%%=*}
      PRIVILEGE_PERMS=''${PRIVILEGE_PERMISSION#*=}
      IFS='.' declare -a 'PRIVILEGE_PERMS=($PRIVILEGE_PERMS)'
      privilege_permissions "$PRIVILEGE_CN" "''${PRIVILEGE_PERMS[@]}"
    done
  '';
  roleScript = pkgs.writeShellScript "ldap-management-rols.sh" ''
    set -eu

    source ${./ldap-common.sh}
    source ${./ldap-sync.sh}

    IFS=',' declare -a 'ROLE_PRIVILEGES=($ROLE_PRIVILEGES)'
    for ROLE_PRIVILEGE in "''${ROLE_PRIVILEGES[@]}"; do
      ROLE_CN=''${ROLE_PRIVILEGE%%=*}
      ROLE_PRIVS=''${ROLE_PRIVILEGE#*=}
      IFS='.' declare -a 'ROLE_PRIVS=($ROLE_PRIVS)'
      role_privileges "$ROLE_CN" "''${ROLE_PRIVS[@]}"
    done
    IFS='+' declare -a 'ROLE_MEMBERS=($ROLE_MEMBERS)'
    for ROLE_MEMBER in "''${ROLE_MEMBERS[@]}"; do
      ROLE_CN=''${ROLE_MEMBER%%=*}
      ROLE_MEMS=''${ROLE_MEMBER#*=}
      IFS='%' declare -a 'ROLE_MEMS=($ROLE_MEMS)'
      role_members "$ROLE_CN" "''${ROLE_MEMS[@]}"
    done
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
      LDAPTLS_CACERT = "/etc/ssl/certs/ca-bundle.crt";
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
        ExecStart = [
          "${managementScript}"
        ];
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
        (mkIf config.security.ipa.enable [ pkgs.freeipa ])
      ];
      restartTriggers = [
        smbSyncGroupNames
        smbSyncUserNames
        sysAccountPasswordFiles
        privilegePermissions
        rolePrivileges
        roleMembers
      ];
      environment = mkMerge [
        ldapEnv
        ldapAuth
        (mapOptionDefaults {
          LDAP_DNSUFFIX_USER = ldap.userDnSuffix;
          LDAP_DNSUFFIX_GROUP = ldap.groupDnSuffix;
          LDAP_DNSUFFIX_SYSACCOUNT = ldap.sysAccountDnSuffix;
          LDAP_DNSUFFIX_PERMISSION = ldap.permissionDnSuffix;
          LDAP_DNSUFFIX_PRIVILEGE = ldap.privilegeDnSuffix;
          LDAP_DNSUFFIX_ROLE = ldap.roleDnSuffix;
          LDAP_DNSUFFIX_HOST = ldap.hostDnSuffix;
          LDAP_DNSUFFIX_HOSTGROUP = ldap.hostGroupDnSuffix;
          LDAP_DNSUFFIX_SERVICE = ldap.serviceDnSuffix;
          SMB_SYNC_GROUPS = concatStringsSep "," smbSyncGroupNames;
          SMB_SYNC_USERS = concatStringsSep "," smbSyncUserNames;
          SYSACCOUNT_PASSWORD_FILES = sysAccountPasswordFiles;
          PRIVILEGE_PERMISSIONS = privilegePermissions;
          ROLE_PRIVILEGES = rolePrivileges;
          ROLE_MEMBERS = roleMembers;
        })
      ];
      serviceConfig = {
        Type = mkOptionDefault "oneshot";
        ExecStart = mkMerge [
          (mkIf (privileges != [ ]) [ "${privilegeScript}" ])
          (mkIf (roles != [ ]) [ "${roleScript}" ])
          [ "${syncScript}" ]
          (mkIf (sysAccounts != [ ]) [ "${sysaccountScript}" ])
        ];
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
