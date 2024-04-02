{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib.lib) mkAlmostOptionDefault mapListToAttrs;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkOptionDefault;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) filter;
  cfg = config.users.ldap;
  ldap'lib = config.lib.ldap;
  sysaccountModule = {config, nixosConfig, name, ldap, ...}: {
    options = with lib.types; {
      enable = mkEnableOption "sys account" // {
        default = true;
      };
      uid = mkOption {
        type = str;
        default = name;
      };
      passwordFile = mkOption {
        type = nullOr path;
        default = null;
      };
      object = mkOption {
        type = ldap.lib.objectSettingsType;
      };
    };
    config = {
      object = {
        enable = mkAlmostOptionDefault config.enable;
        dn = mkOptionDefault (ldap.lib.withBaseDn "uid=${config.uid},${ldap.sysAccountDnSuffix}");
        settings = {
          changeType = mkAlmostOptionDefault "add";
          settings = {
            uid = mkOptionDefault config.uid;
            objectClass' = {
              name = "objectClass";
              initial = true;
              value = [ "account" "simplesecurityobject" ];
            };
            userPassword = {
              initial = true;
              value = mkOptionDefault "initial123";
            };
            passwordExpirationTime = {
              initial = true;
              value = mkOptionDefault "20010101031407Z";
            };
          };
        };
      };
    };
  };
in {
  options.users.ldap = with lib.types; {
    management = {
      sysAccounts = mkOption {
        type = attrsOf (submoduleWith {
          modules = [ sysaccountModule ];
          inherit (config.lib.ldap) specialArgs;
        });
        default = { };
      };
    };
    domainDnSuffix = mkOption {
      type = str;
      default = "";
    };
    hostDnSuffix = mkOption {
      type = str;
      default = "";
    };
    hostGroupDnSuffix = mkOption {
      type = str;
      default = "";
    };
    serviceDnSuffix = mkOption {
      type = str;
      default = "";
    };
    sysAccountDnSuffix = mkOption {
      type = str;
      default = "";
    };
  };
  config.users.ldap = {
    management.objects = let
      sysAccountObjects = mapAttrsToList (_: acc: acc.object) cfg.management.sysAccounts;
      enabledObjects = filter (object: object.enable) sysAccountObjects;
    in mapListToAttrs ldap'lib.mapObjectSettingsToPair enabledObjects;
  };
}
