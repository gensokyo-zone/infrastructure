{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib.lib) mkAlmostOptionDefault mapOptionDefaults mapListToAttrs;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault;
  inherit (lib.attrsets) attrNames mapAttrs mapAttrsToList;
  inherit (lib.lists) filter;
  cfg = config.users.ldap;
  ldap'lib = config.lib.ldap;
  permissionModule = {config, name, ldap, ...}: let
    targetConf = {
      user = {
        location = ldap.userDnSuffix;
        targetFilter = "(objectclass=posixaccount)";
      };
      user-group = {
        location = ldap.groupDnSuffix;
        targetFilter = "(|(objectclass=ipausergroup)(objectclass=posixgroup))";
      };
      permission = {
        location = ldap.permissionDnSuffix;
        targetFilter = "(objectclass=ipapermission)";
      };
      privilege = {
        location = ldap.privilegeDnSuffix;
        targetFilter = "(objectclass=groupofnames)";
      };
      role = {
        location = ldap.roleDnSuffix;
        targetFilter = "(objectclass=groupofnames)";
      };
      samba-domain = {
        location = "";
        target = "sambaDomainName=*,${ldap.base}";
        targetFilter = "(objectclass=sambadomain)";
      };
      domain = {
        location = ldap.domainDnSuffix;
        targetFilter = "(objectclass=ipantdomainattrs)";
        #target = "cn=*";
      };
      host = {
        location = ldap.hostDnSuffix;
        # TODO: targetFilter
        target = "fqdn=*";
      };
      service = {
        location = ldap.serviceDnSuffix;
        # TODO: targetFilter
        target = "krbprincipalname=*";
      };
      sysaccount = {
        location = ldap.sysAccountDnSuffix;
        targetFilter = "(objectclass=account)";
      };
    };
  in {
    options = with lib.types; {
      cn = mkOption {
        type = str;
        default = name;
      };
      bindType = mkOption {
        type = enum [ "anonymous" "permission" "all" ];
        default = "permission";
      };
      rights = mkOption {
        type = oneOf [
          (listOf (enum [ "read" "search" "compare" "write" "add" "delete" ]))
          (enum [ "all" ])
        ];
        default = [ "read" "search" "compare" ];
      };
      targetType = mkOption {
        type = nullOr (enum (attrNames targetConf));
        default = null;
      };
      location = mkOption {
        type = str;
      };
      target = mkOption {
        type = nullOr str;
        default = null;
      };
      targetFilter = mkOption {
        type = nullOr str;
      };
      attrs = mkOption {
        type = listOf str;
      };
      members = mkOption {
        type = listOf str;
        default = [ ];
      };
      object = mkOption {
        type = ldap.lib.objectSettingsType;
      };
    };
    config = let
      conf.targetFilter = mkIf (config.target != null) (mkOptionDefault null);
      conf.object = {
        dn = mkOptionDefault (ldap.lib.withBaseDn "cn=${config.cn},${ldap.permissionDnSuffix}");
        settings = {
          changeType = mkAlmostOptionDefault "add";
          settings = mapOptionDefaults {
            cn = config.cn;
            objectClass = [ "top" "groupofnames" "ipapermission" "ipapermissionv2" ];
            ipaPermissionType = [ "SYSTEM" "V2" ];
            ipaPermIncludedAttr = config.attrs;
            ipaPermBindRuleType = config.bindType;
            ipaPermRight = config.rights;
            ipaPermLocation = ldap.lib.withBaseDn config.location;
          } // {
            member = mkIf (config.members != [ ]) (mkOptionDefault (map ldap.lib.withBaseDn config.members));
            ipaPermTargetFilter = mkIf (config.targetFilter != null) (mkOptionDefault config.targetFilter);
            ipaPermTarget = mkIf (config.target != null) (mkOptionDefault config.target);
          };
        };
      };
      target = {
        location = mkIf (config.targetType != null) (mkAlmostOptionDefault targetConf.${config.targetType}.location);
        targetFilter = mkIf (config.targetType != null) (mkAlmostOptionDefault targetConf.${config.targetType}.targetFilter or null);
        target = mkIf (config.targetType != null) (mkAlmostOptionDefault targetConf.${config.targetType}.target or null);
      };
    in mkMerge [ conf target ];
  };
  privilegeModule = {config, name, ldap, ...}: {
    options = with lib.types; {
      enable = mkEnableOption "privilege" // {
        default = true;
      };
      cn = mkOption {
        type = str;
        default = name;
      };
      permissions = mkOption {
        type = listOf str;
        default = [ ];
      };
      object = mkOption {
        type = ldap.lib.objectSettingsType;
      };
    };
    config = {
      object = {
        enable = mkAlmostOptionDefault config.enable;
        dn = mkOptionDefault (ldap.lib.withBaseDn "cn=${config.cn},${ldap.privilegeDnSuffix}");
        settings = {
          changeType = mkAlmostOptionDefault "add";
          settings = mapOptionDefaults {
            cn = config.cn;
            objectClass = [ "top" "nestedgroup" "groupofnames" ];
          };
        };
      };
    };
  };
  roleModule = {config, name, ldap, ...}: {
    options = with lib.types; {
      enable = mkEnableOption "role" // {
        default = true;
      };
      cn = mkOption {
        type = str;
        default = name;
      };
      privileges = mkOption {
        type = listOf str;
        default = [ ];
      };
      members = mkOption {
        type = listOf str;
        default = [ ];
      };
      object = mkOption {
        type = ldap.lib.objectSettingsType;
      };
    };
    config = {
      object = {
        enable = mkAlmostOptionDefault config.enable;
        dn = mkOptionDefault (ldap.lib.withBaseDn "cn=${config.cn},${ldap.roleDnSuffix}");
        settings = {
          changeType = mkAlmostOptionDefault "add";
          settings = mapOptionDefaults {
            cn = config.cn;
            objectClass = [ "top" "nestedgroup" "groupofnames" ];
            member = mkIf (config.members != [ ]) (mkOptionDefault (map ldap.lib.withBaseDn config.members));
          };
        };
      };
    };
  };
in {
  options.users.ldap = with lib.types; {
    management = {
      permissions = mkOption {
        type = attrsOf (submoduleWith {
          modules = [ permissionModule ];
          inherit (config.lib.ldap) specialArgs;
        });
        default = { };
      };
      privileges = mkOption {
        type = attrsOf (submoduleWith {
          modules = [ privilegeModule ];
          inherit (config.lib.ldap) specialArgs;
        });
        default = { };
      };
      roles = mkOption {
        type = attrsOf (submoduleWith {
          modules = [ roleModule ];
          inherit (config.lib.ldap) specialArgs;
        });
        default = { };
      };
    };
    permissionDnSuffix = mkOption {
      type = str;
    };
    privilegeDnSuffix = mkOption {
      type = str;
    };
    roleDnSuffix = mkOption {
      type = str;
    };
  };
  config.users.ldap = {
    management.objects = let
      permissionObjects = mapAttrsToList (_: perm: perm.object) cfg.management.permissions;
      privilegeObjects = mapAttrsToList (_: priv: priv.object) cfg.management.privileges;
      enabledObjects = filter (object: object.enable) (permissionObjects ++ privilegeObjects);
    in mapListToAttrs ldap'lib.mapObjectSettingsToPair enabledObjects;
  };
}
