{
  config,
  options,
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault mapOptionDefaults;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault mkForce;
  inherit (lib.attrsets) mapAttrs filterAttrs attrNames attrValues listToAttrs mapAttrsToList nameValuePair;
  inherit (lib.lists) filter isList concatMap;
  inherit (lib.strings) toUpper concatMapStringsSep replaceStrings;
  inherit (lib.trivial) flip;
  inherit (lib) generators;
  cfg = config.services.sssd;
  mkValuePrimitive = value:
    if value == true then "True"
    else if value == false then "False"
    else toString value;
  toINI = generators.toINI {
    mkKeyValue = generators.mkKeyValueDefault {
      mkValueString = value:
        if isList value then concatMapStringsSep ", " mkValuePrimitive value
        else mkValuePrimitive value;
    } " = ";
  };
  primitiveType = with lib.types; oneOf [ str int bool ];
  valueType = with lib.types; oneOf [ primitiveType (listOf primitiveType) ];
  settingsType = lib.types.attrsOf valueType;
  serviceModule = { name, ... }: {
    options = with lib.types; {
      enable = mkEnableOption "${name} service";
      name = mkOption {
        type = str;
        default = name;
        readOnly = true;
      };
      settings = mkOption {
        type = settingsType;
        default = { };
      };
    };
  };
  nssModule = { nixosConfig, ... }: {
    options = {
      # TODO: passwd.enable = mkEnableOption "passwd" // { default = true; };
      shadow.enable = mkEnableOption "shadow" // { default = nixosConfig.services.sssd.services.pam.enable; };
      netgroup.enable = mkEnableOption "netgroup" // { default = true; };
    };
  };
  domainModule = { name, ... }: {
    options = with lib.types; {
      enable = mkEnableOption "domain" // {
        default = true;
      };
      domain = mkOption {
        type = str;
        default = name;
      };
      settings = mkOption {
        type = settingsType;
      };
    };
  };
  domainLdapModule = { config, ... }: let
    cfg = config.ldap;
  in {
    options.ldap = with lib.types; {
      extraAttrs.user = mkOption {
        type = attrsOf str;
        default = { };
      };
      authtok = {
        type = mkOption {
          type = enum [ "password" "obfuscated_password" ];
          default = "password";
        };
        password = mkOption {
          type = nullOr str;
          default = null;
        };
        passwordFile = mkOption {
          type = nullOr path;
          default = null;
        };
        passwordVar = mkOption {
          type = str;
          internal = true;
          default = "SSSD_AUTHTOK_" + replaceStrings [ "-" "." ] [ "_" "_" ] (toUpper config.domain);
        };
      };
    };
    config = let
      authtokConfig = mkIf (cfg.authtok.password != null || cfg.authtok.passwordFile != null) {
        ldap_default_authtok_type = mkOptionDefault cfg.authtok.type;
        ldap_default_authtok = mkOptionDefault (
          if cfg.authtok.passwordFile != null then "\$${cfg.authtok.passwordVar}"
          else cfg.authtok.password
        );
      };
      extraAttrsConfig = mkIf (cfg.extraAttrs.user != { }) {
        ldap_user_extra_attrs = let
          mkAttr = name: attr: "${name}:${attr}";
        in mapAttrsToList mkAttr cfg.extraAttrs.user;
      };
    in {
      settings = mkMerge [
        authtokConfig
        extraAttrsConfig
      ];
    };
  };
in {
  options.services.sssd = with lib.types; {
    debugLevel = mkOption {
      type = ints.between 16 65520;
      default = 16;
    };
    domains = mkOption {
      type = attrsOf (submoduleWith {
        modules = [ domainModule domainLdapModule ];
        specialArgs = {
          nixosConfig = config;
        };
      });
      default = {
        shadowutils.settings = mapOptionDefaults {
          id_provider = "proxy";
          proxy_lib_name = "files";
          auth_provider = "proxy";
          proxy_pam_target = "sssd-shadowutils";
          proxy_fast_alias = true;
        };
      };
    };
    services = let
      mkServiceOption = name: { modules ? [ ] }: mkOption {
        type = submoduleWith {
          modules = [ serviceModule ] ++ modules;
          specialArgs = {
            inherit name;
            nixosConfig = config;
          };
        };
      };
      services = {
        nss = { modules = [ nssModule ]; };
        pam = { };
        ifp = { };
        sudo = { };
        autofs = { };
        ssh = { };
        pac = { };
      };
    in mapAttrs mkServiceOption services;
    settings = mkOption {
      type = attrsOf settingsType;
    };
    configText = mkOption {
      type = nullOr lines;
    };
  };
  config.services.sssd = let
    enabledDomains = filter (domain: domain.enable) (attrValues cfg.domains);
    enabledServices = filterAttrs (_: service: service.enable) cfg.services;
  in {
    settings = let
      serviceSettings = mapAttrs (name: service: mapOptionDefaults service.settings) enabledServices;
      defaultSettings = {
        sssd = mapOptionDefaults {
          config_file_version = 2;
          debug_level = cfg.debugLevel;
          services = mapAttrsToList (_: service: service.name) enabledServices;
          domains = map (domain: domain.domain) enabledDomains;
        };
      };
      domainSettings = map (domain: {
        "domain/${domain.domain}" = mapAttrs (_: mkOptionDefault) domain.settings;
      }) enabledDomains;
      settings = [ defaultSettings serviceSettings ] ++ domainSettings;
    in mkMerge settings;
    services = {
      nss.enable = mkAlmostOptionDefault true;
      pam.enable = mkAlmostOptionDefault true;
      ifp.settings = let
        extraUserAttrs = listToAttrs (concatMap (domain: map (flip nameValuePair {}) (attrNames domain.ldap.extraAttrs.user)) enabledDomains);
        mkExtraAttr = name: _: "+${name}";
      in {
        user_attributes = mkIf (extraUserAttrs != { }) (mkOptionDefault (
          mapAttrsToList mkExtraAttr extraUserAttrs
        ));
      };
      sudo = { };
      autofs = { };
      ssh = { };
      pac = { };
    };
    configText = mkOptionDefault (toINI cfg.settings);
    config = mkIf (cfg.configText != null) (mkAlmostOptionDefault cfg.configText);
  };
  config.system.nssDatabases = let
    inherit (cfg.services) nss;
  in mkIf cfg.enable {
    ${if options ? system.nssDatabases.netgroup then "netgroup" else null} = mkIf (nss.enable && nss.netgroup.enable) [ "sss" ];
    shadow = mkIf (!nss.enable || !nss.shadow.enable) (
      mkForce [ "files" ]
    );
  };
}
