{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
  inherit (config.users) ldap;
  inherit (ldap.management) permissions;
in {
  config.users.ldap.management = {
    enable = mkDefault true;
    permissions = {
      "Custom Anonymous User Read" = {
        bindType = "anonymous";
        targetType = "user";
        attrs = ["gidnumber" "homedirectory" "ipantsecurityidentifier" "loginshell" "manager" "objectclass" "title" "uid" "uidnumber"];
      };
      "Custom Permission Admin" = {
        location = ldap.permissionDnSuffix;
        target = "cn=*";
        rights = "all";
        attrs = [
          "member"
          "cn"
          "o"
          "ou"
          "owner"
          "description"
          "objectclass"
          "seealso"
          "businesscategory"
          "ipapermtarget"
          "ipapermright"
          "ipapermincludedattr"
          "ipapermbindruletype"
          "ipapermexcludedattr"
          "ipapermtargetto"
          "ipapermissiontype"
          "ipapermlocation"
          "ipapermdefaultattr"
          "ipapermtargetfrom"
          "ipapermtargetfilter"
        ];
      };
      "Custom Privilege Admin" = {
        location = ldap.privilegeDnSuffix;
        target = "cn=*";
        rights = "all";
        attrs = [
          "member"
          "memberof"
          "cn"
          "o"
          "ou"
          "owner"
          "description"
          "objectclass"
          "seealso"
          "businesscategory"
        ];
      };
      "Custom Role Admin" = {
        location = ldap.roleDnSuffix;
        target = "cn=*";
        rights = "all";
        attrs = [
          "member"
          "memberof"
          "cn"
          "o"
          "ou"
          "owner"
          "description"
          "objectclass"
          "seealso"
          "businesscategory"
        ];
      };
      "Custom Role Modify" = {
        targetType = "role";
        rights = ["write" "add"];
        attrs = permissions."Custom Role Admin".attrs;
      };
      "Custom Host Permission" = {
        targetType = "host";
        rights = ["write"];
        attrs = [
          "memberof"
        ];
      };
      "Custom SysAccount Permission" = {
        targetType = "sysaccount";
        rights = "all";
        attrs = [
          "member"
          "memberof"
          "uid"
          "o"
          "ou"
          "description"
          "objectclass"
          "seealso"
          "businesscategory"
          "passwordExpirationTime"
          "nsIdleTimeout"
        ];
      };
      "Custom SysAccount Admin" = {
        location = ldap.sysAccountDnSuffix;
        target = "uid=*";
        rights = ["add" "write" "delete"];
        attrs =
          permissions."Custom SysAccount Permission".attrs
          ++ [
            "userPassword"
          ];
      };
      "Custom Service Permission" = {
        targetType = "service";
        rights = ["write"];
        attrs = [
          "memberof"
        ];
      };
    };
    privileges = {
      "Custom Management Admin" = {
        permissions = [
          "Custom Permission Admin"
          "Custom Privilege Admin"
          "Custom Role Admin"
          "Custom Role Modify"
          "Custom Host Permission"
          "Custom SysAccount Permission"
          "Custom SysAccount Admin"
          "Custom Service Permission"
        ];
      };
    };
    roles = {
      "Security Architect" = {
        privileges = [
          "Custom Management Admin"
          # you can't manage roles if you can't see them .-.
          "RBAC Readers"
        ];
        # allow reimu to actually make these changes...
        members = [
          "fqdn=reimu.${config.networking.domain},${ldap.hostDnSuffix}"
        ];
      };
    };
    sysAccounts = {
      peep = {
        passwordFile = config.sops.secrets.ldap-peep-password.path;
      };
      keycloak = {
        passwordFile = config.sops.secrets.ldap-keycloak-password.path;
      };
    };
    objects = {
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
    };
  };
  config.sops.secrets = let
    sopsFile = mkDefault ../secrets/ldap.yaml;
  in {
    ldap-peep-password = {
      inherit sopsFile;
    };
    ldap-keycloak-password = {
      inherit sopsFile;
    };
  };
}
