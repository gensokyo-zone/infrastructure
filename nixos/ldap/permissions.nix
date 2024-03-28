{config, lib, ...}: let
  inherit (lib.modules) mkDefault;
  inherit (config.users) ldap;
  inherit (ldap.management) permissions;
  adminPriv = "cn=Custom Management Admin,${ldap.privilegeDnSuffix}";
in {
  config.users.ldap.management = {
    enable = mkDefault true;
    permissions = {
      "Custom Anonymous User Read" = {
        bindType = "anonymous";
        targetType = "user";
        attrs = [ "gidnumber" "homedirectory" "ipantsecurityidentifier" "loginshell" "manager" "objectclass" "title" "uid" "uidnumber" ];
      };
      "Custom Permission Admin" = {
        location = ldap.permissionDnSuffix;
        target = "cn=*";
        rights = "all";
        members = [ adminPriv ];
        attrs = [
          "member" "cn" "o" "ou" "owner" "description" "objectclass" "seealso" "businesscategory"
          "ipapermtarget" "ipapermright" "ipapermincludedattr" "ipapermbindruletype" "ipapermexcludedattr" "ipapermtargetto" "ipapermissiontype" "ipapermlocation" "ipapermdefaultattr" "ipapermtargetfrom" "ipapermtargetfilter"
        ];
      };
      "Custom Privilege Admin" = {
        location = ldap.privilegeDnSuffix;
        target = "cn=*";
        rights = "all";
        members = [ adminPriv ];
        attrs = [
          "member" "memberof" "cn" "o" "ou" "owner" "description" "objectclass" "seealso" "businesscategory"
        ];
      };
      "Custom Role Admin" = {
        location = ldap.roleDnSuffix;
        target = "cn=*";
        rights = "all";
        members = [ adminPriv ];
        attrs = [
          "member" "memberof" "cn" "o" "ou" "owner" "description" "objectclass" "seealso" "businesscategory"
        ];
      };
      "Custom Role Modify" = {
        targetType = "role";
        rights = [ "write" ];
        members = [ adminPriv ];
        attrs = permissions."Custom Role Admin".attrs;
      };
      "Custom Host Permission" = {
        targetType = "host";
        rights = [ "write" ];
        members = [ adminPriv ];
        attrs = [
          "memberof"
        ];
      };
      "Custom SysAccount Permission" = {
        targetType = "sysaccount";
        rights = [ "write" ];
        members = [ adminPriv ];
        attrs = [
          "memberof"
        ];
      };
      "Custom Service Permission" = {
        targetType = "service";
        rights = [ "write" ];
        members = [ adminPriv ];
        attrs = [
          "memberof"
        ];
      };
    };
    objects = {
      ${adminPriv} = {
        changeType = "add";
        settings = {
          objectClass = [ "top" "nestedgroup" "groupofnames" ];
          member = map config.lib.ldap.withBaseDn [
            "cn=Security Architect,${ldap.roleDnSuffix}"
          ];
        };
      };
      # change default public access
      "cn=System: Read User Compat Tree,${ldap.permissionDnSuffix}" = {
        settings.ipaPermBindRuleType = "all";
      };
      "cn=System: Read User Views Compat Tree,${ldap.permissionDnSuffix}" = {
        settings.ipaPermBindRuleType = "all";
      };
      "cn=System: Read User Standard Attributes,${ldap.permissionDnSuffix}" = {
        settings.ipaPermBindRuleType = "all";
      };
      # allow reimu to actually make these changes...
      "cn=Security Architect,${ldap.roleDnSuffix}" = {
        settings.member = [ "fqdn=reimu.${config.networking.domain},${ldap.hostDnSuffix}${ldap.base}" ];
      };
    };
  };
}
