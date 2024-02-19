{
  config,
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault mkOverride;
  inherit (lib.lists) filter elem;
  inherit (lib.attrsets) nameValuePair attrValues;
  inherit (gensokyo-zone.lib) unmerged;
  inherit (gensokyo-zone) meta;
  cfg = config.gensokyo-zone.users;
  userModule = {
    gensokyo-zone,
    nixosConfig,
    config,
    name,
    ...
  }: let
    inherit (gensokyo-zone.lib) json unmerged;
    cfg = nixosConfig.gensokyo-zone.users;
    isValidGroup = group: ! elem group cfg.excludeGroups && cfg.groups.${group}.enable;
    mapGroupToSystem = group: cfg.groups.${group}.systemName;
  in {
    freeformType = json.types.attrs;
    options = with lib.types; {
      enable =
        mkEnableOption "user"
        // {
          default = true;
        };
      name = mkOption {
        type = str;
        default = name;
      };
      systemName = mkOption {
        type = str;
        default = config.name;
      };
      systemUser = mkOption {
        type = unspecified;
        readOnly = true;
      };
      uid = mkOption {
        type = int;
      };
      group = mkOption {
        type = str;
      };
      extraGroups = mkOption {
        type = listOf str;
        default = [];
      };
      systemGroup = mkOption {
        type = str;
      };
      systemGroups = mkOption {
        type = listOf str;
      };
      setUser = mkOption {
        type = unmerged.type;
      };
    };
    config = {
      systemUser = nixosConfig.users.users.${config.systemName};
      systemGroup = mkOptionDefault (mapGroupToSystem config.group);
      systemGroups = mkOptionDefault (map mapGroupToSystem (
        filter isValidGroup config.extraGroups
      ));
      setUser = {
        uid = mkDefault config.uid;
        name = mkDefault config.systemName;
        autoSubUidGidRange = mkDefault false;
        group = mkIf (isValidGroup config.group) (
          mkDefault (mapGroupToSystem config.group)
        );
        isSystemUser = mkOverride 1250 (!config.systemUser.isNormalUser);
        extraGroups = config.systemGroups;
        openssh.authorizedKeys = mkIf (config.systemUser.isNormalUser && config.openssh.authorizedKeys or {} != {}) (
          config.openssh.authorizedKeys
        );
      };
    };
  };
  groupModule = {
    gensokyo-zone,
    nixosConfig,
    config,
    name,
    ...
  }: let
    inherit (gensokyo-zone.lib) json unmerged;
    cfg = nixosConfig.gensokyo-zone.users;
    isValidUser = user: ! elem user cfg.excludeUsers && cfg.users.${user}.enable;
    mapUserToSystem = user: cfg.users.${user}.systemName;
  in {
    freeformType = json.types.attrs;
    options = with lib.types; {
      enable =
        mkEnableOption "group"
        // {
          default = true;
        };
      name = mkOption {
        type = str;
        default = name;
      };
      systemName = mkOption {
        type = str;
        default = config.name;
      };
      systemGroup = mkOption {
        type = unspecified;
        readOnly = true;
      };
      gid = mkOption {
        type = int;
      };
      members = mkOption {
        type = listOf str;
      };
      systemMembers = mkOption {
        type = listOf str;
      };
      setGroup = mkOption {
        type = unmerged.type;
      };
    };
    config = {
      systemGroup = nixosConfig.users.groups.${config.systemName};
      systemMembers = mkOptionDefault (map mapUserToSystem (
        filter isValidUser config.members
      ));
      setGroup = {
        gid = mkDefault config.gid;
        name = mkDefault config.systemName;
        members = config.systemMembers;
        openssh.authorizedKeys = mkIf (config.systemUser.isNormalUser && config.openssh.authorizedKeys or {} != {}) (
          config.openssh.authorizedKeys
        );
      };
    };
  };
  usersModule = {
    gensokyo-zone,
    nixosConfig,
    config,
    ...
  }: let
    inherit (gensokyo-zone.lib) unmerged;
    specialArgs = {
      inherit gensokyo-zone nixosConfig;
    };
    enabledUsers = filter (user: user.enable) (attrValues config.users);
    enabledGroups = filter (group: group.enable) (attrValues config.groups);
  in {
    options = with lib.types; {
      enable = mkEnableOption "gensokyo-zone users";
      users = mkOption {
        type = attrsOf (submoduleWith {
          modules = [userModule];
          inherit specialArgs;
        });
        default = { };
      };
      excludeUsers = mkOption {
        type = listOf str;
      };
      groups = mkOption {
        type = attrsOf (submoduleWith {
          modules = [groupModule];
          inherit specialArgs;
        });
        default = { };
      };
      excludeGroups = mkOption {
        type = listOf str;
      };
      setUsers = mkOption {
        type = unmerged.types.attrs;
        internal = true;
      };
    };
    config = {
      excludeUsers = [];
      excludeGroups = [
        "users"
        "wheel"
      ];
      setUsers = {
        users = map (user:
          nameValuePair user.systemName (
            unmerged.merge user.setUser
          ))
        enabledUsers;
        groups = map (group:
          nameValuePair group.systemName (
            unmerged.merge group.setGroup
          ))
        enabledGroups;
      };
    };
  };
in {
  options.gensokyo-zone.users = mkOption {
    type = lib.types.submoduleWith {
      modules = [usersModule];
      specialArgs = {
        inherit gensokyo-zone;
        inherit (gensokyo-zone) inputs;
        nixosConfig = config;
      };
    };
  };

  config = {
    gensokyo-zone.users = {...}: {
      imports = [
        meta.nixos.users
      ];
    };
    users = mkIf cfg.enable (
      unmerged.mergeAttrs cfg.setUsers
    );
    lib.gensokyo-zone.users = {
      inherit cfg usersModule userModule groupModule;
    };
  };
}
