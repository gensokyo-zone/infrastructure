{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib.lib) mapOptionDefaults;
  inherit (lib.options) mkEnableOption;
  inherit (lib.modules) mkIf mkOptionDefault;
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
  objectClassAttr = "objectClass";
  sidAttr = "ipaNTSecurityIdentifier";
  ntHashAttr = "ipaNTHash";
  authTypeAttr = "ipaUserAuthType";
  userSearchAttrs = [ objectClassAttr sidAttr authTypeAttr ntHashAttr ];
  groupSearchAttrs = [ objectClassAttr sidAttr ];
  managementScript = pkgs.writeShellScript "ldap-management.sh" ''
    set -eu

    ldapsearch() {
      command ldapsearch -QLLL -o ldif_wrap=no "$@"
    }

    ldapmodify() {
      command ldapmodify -Q "$@"
    }

    ldap_parse() {
      local LDAP_ATTR=$1 LDAP_LIMIT LDAP_LINE LDAP_COUNT=0
      shift 1
      local LDAP_LIMIT=''${1-1}

      while read -r LDAP_LINE; do
        if [[ $LDAP_LIMIT -eq 0 ]]; then
          break
        fi
        if [[ $LDAP_LINE = "$LDAP_ATTR:: "* ]]; then
          printf '%s\n' "$LDAP_LINE" | cut -d ' ' -f 2- | base64 -d
        elif [[ $LDAP_LINE = "$LDAP_ATTR: "* ]]; then
          printf '%s\n' "$LDAP_LINE" | cut -d ' ' -f 2-
        else
          continue
        fi
        LDAP_COUNT=$((LDAP_COUNT+1))
        LDAP_LIMIT=$((LDAP_LIMIT-1))
      done
      if [[ $LDAP_COUNT -eq 0 ]]; then
        echo "$LDAP_ATTR not found" >&2
        return 1
      fi
    }

    smbsync_group() {
      local LDAP_GROUP_CN=$1 SMB_GROUP_DATA SMB_GROUP_SID
      shift 1

      echo "updating cn=''${LDAP_GROUP_CN},${ldap.groupDnSuffix} ..." >&2
      SMB_GROUP_DATA=$(ldapsearch -z1 \
        -b "${ldap.groupDnSuffix}${ldap.base}" \
        "(&(cn=$LDAP_GROUP_CN)(${objectClassAttr}=posixgroup))" \
        ${escapeShellArgs groupSearchAttrs}
      )
      SMB_GROUP_SID=$(ldap_parse ${sidAttr} <<< "$SMB_GROUP_DATA")
      ldapmodify <<EOF
    dn: cn=$LDAP_GROUP_CN,${ldap.groupDnSuffix}${ldap.base}
    changetype: modify
    replace: sambaSID
    sambaSID: $SMB_GROUP_SID
    -
    EOF
    }

    smbsync_user() {
      local LDAP_USER_UID=$1 SMB_USER_DATA SMB_USER_SID SMB_USER_NTPASS
      shift 1

      echo "updating uid=''${LDAP_USER_UID},${ldap.userDnSuffix} ..." >&2
      SMB_USER_DATA=$(ldapsearch -z1 \
        -b "${ldap.userDnSuffix}${ldap.base}" \
        "(&(uid=$LDAP_USER_UID)(${objectClassAttr}=posixaccount))" \
        ${escapeShellArgs userSearchAttrs}
      )
      SMB_USER_SID=$(ldap_parse ${sidAttr} <<< "$SMB_USER_DATA")
      SMB_USER_NTPASS=$(ldap_parse ${ntHashAttr} <<< "$SMB_USER_DATA" | xxd -p)
      SMB_USER_NTPASS=''${SMB_USER_NTPASS^^}
      ldapmodify <<EOF
    dn: uid=$LDAP_USER_UID,${ldap.userDnSuffix}${ldap.base}
    changetype: modify
    replace: sambaSID
    sambaSID: $SMB_USER_SID
    -
    replace: sambaNTPassword
    sambaNTPassword: $SMB_USER_NTPASS
    -
    EOF
    }

    ldapwhoami

    ldapmodify -cf "$MAN_LDAP_ADD" || true

    ldapmodify -c -f "$MAN_LDAP_MODIFY" || true

    ldapmodify -f "$MAN_LDAP_DELETE"

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
  config = mkIf cfg.enable {
    systemd.services.ldap-management = rec {
      wantedBy = [ "multi-user.target" ];
      wants = [ "krb5-host.service" ];
      after = wants;
      path = [ config.services.openldap.package pkgs.coreutils pkgs.xxd ];
      environment = mapOptionDefaults {
        LDAPBASE = ldap.base;
        LDAPURI = "ldaps://ldap.int.${config.networking.domain}";
        LDAPSASL_MECH = "GSSAPI";
        LDAPSASL_AUTHCID = "dn:fqdn=${config.networking.fqdn},${ldap.hostDnSuffix}${ldap.base}";
        # LDAPBINDDN?
        SMB_SYNC_GROUPS = concatStringsSep "," (map (group: group.name) smbSyncGroups);
        SMB_SYNC_USERS = concatStringsSep "," (map (user: user.uid) smbSyncUsers);
        MAN_LDAP_ADD = "${additions}";
        MAN_LDAP_MODIFY = "${modifications}";
        MAN_LDAP_DELETE = "${deletions}";
      };
      serviceConfig = {
        Type = mkOptionDefault "oneshot";
        ExecStart = [ "${managementScript}" ];
      };
    };
  };
}
