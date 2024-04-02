{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib.lib) unmerged mkAlmostOptionDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkOptionDefault;
  inherit (lib.attrsets) filterAttrs mapAttrsToList nameValuePair;
  inherit (lib.lists) optional toList;
  inherit (lib.strings) hasSuffix removeSuffix concatMapStrings concatStringsSep concatStrings optionalString;
  ldap'lib = {
    specialArgs = {
      nixosConfig = config;
      ldap = config.users.ldap // {
        lib = config.lib.ldap;
      };
    };
    objectModule = ldapObjectModule;
    objectType = lib.types.submoduleWith {
      modules = [ ldapObjectModule ];
      inherit (ldap'lib) specialArgs;
    };
    objectSettingType' = lib.types.submoduleWith {
      modules = [ ldapObjectSettingModule ];
      inherit (ldap'lib) specialArgs;
    };
    objectSettingType = let
      mapToObjectSetting = value: {
        inherit value;
      };
    in lib.types.coercedTo ldapValueType mapToObjectSetting ldap'lib.objectSettingType';
    objectSettingsModule = ldapObjectSettingsModule;
    objectSettingsType = lib.types.submoduleWith {
      modules = [ ldapObjectSettingsModule ];
      inherit (ldap'lib) specialArgs;
    };
    mapObjectSettingsToPair = settings: nameValuePair
      (ldap'lib.withoutBaseDn settings.dn)
      (unmerged.mergeAttrs settings.settings);
    mapObjectSettingsToAttr = settings: let
      pair = ldap'lib.mapObjectSettingsToPair settings;
    in {
      ${pair.name} = pair.value;
    };
    mkLdapModifyObjectSettingValues = let
      mkLdapModifyValues = setting: concatMapStrings (value: ''
        ${setting.name}: ${toString value}
      '') (toList setting.value);
    in mkLdapModifyValues;
    mkLdapModifyObjectSettings = let
      mkLdapModifySetting = setting: ''
        ${setting.modifyType}: ${setting.name}
      '' + ldap'lib.mkLdapModifyObjectSettingValues setting;
    in settings: mapAttrsToList (_: mkLdapModifySetting) settings;
    mkLdapAddObjectSettings = settings: mapAttrsToList (_: ldap'lib.mkLdapModifyObjectSettingValues) settings;
    mkLdapModifyObject = let
      mkHeader = changeType: object: ''
        dn: ${object.dn}
        changetype: ${changeType}
      '';
    in {
      modify = object: let
        enabledSettings' = filterAttrs (_: setting: setting.enable && !setting.initial) object.settings;
        enabledSettings = ldap'lib.mkLdapModifyObjectSettings enabledSettings';
        replaceSettings' = filterAttrs (_: setting: setting.modifyType == "replace") enabledSettings';
        replaceSettings = ldap'lib.mkLdapModifyObjectSettings replaceSettings';
        addSettings' = filterAttrs (_: setting: setting.modifyType == "add") enabledSettings';
        replaceText = mkHeader "modify" object + concatStringsSep "-\n" replaceSettings;
        text = mkHeader "modify" object + concatStringsSep "-\n" enabledSettings;
      in concatStringsSep "-\n\n" (
        [ text ]
        ++ optional (addSettings' != { }) replaceText
      );
      add = object: let
        enabledSettings = filterAttrs (_: setting: setting.enable) object.settings;
        addSettings = ldap'lib.mkLdapAddObjectSettings enabledSettings;
        modifyAfter = "\n" + ldap'lib.mkLdapModifyObject.modify object;
      in mkHeader "add" object + concatStrings addSettings + modifyAfter;
      delete = object: mkHeader "delete" object;
      modrdn = object: { newrdn, deleteoldrdn, newsuperior }: let
        modifySettings = ''
          newrdn: ${newrdn}
          deleteoldrdn: ${if deleteoldrdn == true then "1" else if deleteoldrdn == "false" then "0" else toString deleteoldrdn}
        '' + optionalString (newsuperior != null) ''
          newsuperior: ${newsuperior}
        '';
      in mkHeader "modrdn" + modifySettings;
      moddn = object: { deleteoldrdn, newsuperior }: let
        modifySettings = ''
          deleteoldrdn: ${if deleteoldrdn == true then "1" else if deleteoldrdn == "false" then "0" else toString deleteoldrdn}
          newsuperior: ${newsuperior}
        '';
      in mkHeader "moddn" + modifySettings;
    };
    withBaseDn = dn:
      if hasSuffix ",${config.users.ldap.base}" dn then dn
      else if hasSuffix "," dn || dn == "" then "${dn}${config.users.ldap.base}"
      else "${dn},${config.users.ldap.base}";
    withoutBaseDn = removeSuffix ",${config.users.ldap.base}";
  };
  ldapPrimitiveType = with lib.types; oneOf [ str int ];
  ldapValueType = with lib.types; oneOf [ ldapPrimitiveType (listOf ldapPrimitiveType) ];
  ldapObjectSettingModule = {config, name, ...}: {
    options = with lib.types; {
      enable = mkEnableOption "setting" // {
        default = true;
      };
      name = mkOption {
        type = str;
        default = name;
      };
      value = mkOption {
        type = ldapValueType;
      };
      initial = mkOption {
        type = bool;
        default = false;
      };
      modifyType = mkOption {
        type = enum [ "replace" "add" "delete" ];
        default = "replace";
      };
    };
  };
  ldapObjectSettingsModule = {config, ...}: {
    options = with lib.types; {
      enable = mkEnableOption "object" // {
        default = true;
      };
      dn = mkOption {
        type = str;
      };
      settings = mkOption {
        type = unmerged.types.attrs;
      };
    };
    config = {
      settings = {
        dn = mkAlmostOptionDefault config.dn;
      };
    };
  };
  ldapObjectModule = {config, name, ldap, ...}: {
    options = with lib.types; {
      enable = mkEnableOption "object creation" // {
        default = true;
      };
      dn = mkOption {
        type = str;
        default = ldap.lib.withBaseDn "${name}";
      };
      changeType = mkOption {
        type = enum [ "modify" "add" "delete" "modrdn" "moddn" ];
        default = "modify";
      };
      changeText = mkOption {
        type = lines;
      };
      objectClasses = mkOption {
        type = listOf str;
        default = [ ];
        description = "additional object classes";
      };
      settings = mkOption {
        type = attrsOf ldap.lib.objectSettingType;
        default = { };
      };
    };
    config = {
      settings = {
        objectClasses' = mkIf (config.objectClasses != [ ]) (mkOptionDefault {
          name = "objectClass";
          modifyType = "add";
          value = config.objectClasses;
        });
      };
      changeText = mkOptionDefault (ldap'lib.mkLdapModifyObject.${config.changeType} config);
    };
  };
in {
  options.users.ldap = with lib.types; {
    management.objects = mkOption {
      type = attrsOf ldap'lib.objectType;
      default = { };
    };
  };
  config.lib.ldap = ldap'lib;
}
