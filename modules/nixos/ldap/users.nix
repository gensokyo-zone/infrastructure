{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib.lib) mkAlmostOptionDefault mapListToAttrs;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  inherit (lib.attrsets) mapAttrs mapAttrsToList;
  inherit (lib.lists) filter;
  inherit (lib.strings) concatStrings;
  cfg = config.users.ldap;
  ldap'lib = config.lib.ldap;
  userModule = {config, nixosConfig, name, ldap, ...}: let
    user = nixosConfig.users.users.${config.user.name};
    sambaAccountFlags = {
      normalUser = "U";
      disabled = "D";
      homeRequired = "H";
      temporaryDuplicate = "T";
      mnsLogon = "M";
      workstationTrust = "W";
      serverTrust = "S";
      domainTrust = "I";
      autoLock = "L";
      noPasswordExpiry = "X";
      noPasswordRequired = "N";
    };
    mkSambaAccountFlags = flags: let
      empty = " ";
      flagChar = char: flag: if flag then char else empty;
      flagChars = mapAttrsToList (name: flagChar sambaAccountFlags.${name}) flags;
    in "[${concatStrings flagChars}]";
  in {
    options = with lib.types; {
      user = {
        enable = mkEnableOption "system user";
        name = mkOption {
          type = nullOr str;
          default = null;
        };
        uid = mkOption {
          type = nullOr int;
          default = null;
        };
      };
      uid = mkOption {
        type = str;
        default = name;
      };
      samba = {
        enable = mkEnableOption "SMB user";
        sync.enable = mkEnableOption "IPA data sync";
        sid = mkOption {
          type = nullOr str;
          default = null;
        };
        accountFlags = mapAttrs (_: _: mkOption {
          type = bool;
          default = false;
        }) sambaAccountFlags;
      };
      object = mkOption {
        type = ldap.lib.objectSettingsType;
      };
    };
    config = {
      user = {
        name = mkIf config.user.enable (mkAlmostOptionDefault name);
        uid = mkIf (config.user.name != null) (mkAlmostOptionDefault user.uid);
      };
      samba = {
        sid = mkIf (ldap.samba.domainSID != null && config.user.uid != null) (
          mkAlmostOptionDefault "${ldap.samba.domainSID}-${toString (ldap.samba.sidUserOffset + config.user.uid)}"
        );
        accountFlags = {
          normalUser = mkIf (config.user.name != null) (mkAlmostOptionDefault user.isNormalUser);
        };
      };
      object = {
        enable = mkAlmostOptionDefault config.samba.enable;
        dn = mkOptionDefault "uid=${config.uid},${ldap.userDnSuffix}${ldap.base}";
        settings = {
          objectClasses = mkIf config.samba.enable [ "sambaSamAccount" ];
          settings = mkIf config.samba.enable {
            sambaSID = mkIf (config.samba.sid != null) (mkOptionDefault config.samba.sid);
            sambaAcctFlags = mkOptionDefault (mkSambaAccountFlags config.samba.accountFlags);
          };
        };
      };
    };
  };
  groupModule = {config, nixosConfig, name, ldap, ...}: let
    group = nixosConfig.users.groups.${config.group.name};
  in {
    options = with lib.types; {
      group = {
        enable = mkEnableOption "system group";
        name = mkOption {
          type = nullOr str;
          default = null;
        };
        gid = mkOption {
          type = nullOr int;
          default = null;
        };
      };
      name = mkOption {
        type = str;
        default = name;
      };
      samba = {
        enable = mkEnableOption "SMB group";
        sync.enable = mkEnableOption "IPA data sync";
        sid = mkOption {
          type = nullOr str;
          default = null;
        };
        groupType = mkOption {
          type = int;
          default = 2;
          description = "http://pig.made-it.com/samba-accounts.html#22762";
        };
      };
      object = mkOption {
        type = ldap.lib.objectSettingsType;
      };
    };
    config = {
      group = {
        name = mkIf config.group.enable (mkAlmostOptionDefault name);
        gid = mkIf (config.group.name != null) (mkAlmostOptionDefault group.gid);
      };
      samba = {
        sid = mkIf (ldap.samba.domainSID != null && config.group.gid != null) (
          mkAlmostOptionDefault "${ldap.samba.domainSID}-${toString (ldap.samba.sidGroupOffset + config.group.gid)}"
        );
      };
      object = {
        enable = mkAlmostOptionDefault config.samba.enable;
        dn = mkOptionDefault "cn=${config.name},${ldap.groupDnSuffix}${ldap.base}";
        settings = {
          objectClasses = mkIf config.samba.enable [ "sambaGroupMapping" ];
          settings = mkIf config.samba.enable {
            sambaSID = mkIf (config.samba.sid != null) (mkOptionDefault config.samba.sid);
            sambaGroupType = mkOptionDefault config.samba.groupType;
          };
        };
      };
    };
  };
in {
  options.users.ldap = with lib.types; {
    management = {
      users = mkOption {
        type = attrsOf (submoduleWith {
          modules = [ userModule ];
          inherit (config.lib.ldap) specialArgs;
        });
        default = { };
      };
      groups = mkOption {
        type = attrsOf (submoduleWith {
          modules = [ groupModule ];
          inherit (config.lib.ldap) specialArgs;
        });
        default = { };
      };
    };
    samba = {
      domainSID = mkOption {
        type = nullOr str;
        default = null;
      };
      sidUserOffset = mkOption {
        type = int;
        default = -7999;
      };
      sidGroupOffset = mkOption {
        type = int;
        default = 256 + 1;
      };
    };
    userDnSuffix = mkOption {
      type = str;
      default = "";
    };
    groupDnSuffix = mkOption {
      type = str;
      default = "";
    };
  };
  config.users.ldap = {
    management.objects = let
      userObjects = mapAttrsToList (_: user: user.object) cfg.management.users;
      groupObjects = mapAttrsToList (_: group: group.object) cfg.management.groups;
      enabledObjects = filter (object: object.enable) (userObjects ++ groupObjects);
    in mapListToAttrs ldap'lib.mapObjectSettingsToPair enabledObjects;
  };
}
