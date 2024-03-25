{ config, lib, utils, ... }: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) head;
  inherit (lib.strings) splitString;
  inherit (utils) escapeSystemdPath;
  mountModule = { config, name, ... }: {
    options = with lib.types; {
      source = mkOption {
        type = path;
        default = "${config.rootDir}/${config.subpath}";
      };
      path = mkOption {
        type = path;
      };
      subpath = mkOption {
        type = str;
        default = name;
      };
      root = mkOption {
        type = path;
        default = "${config.rootDir}/${head (splitString "/" config.subpath)}";
      };
      mountUnit = mkOption {
        type = nullOr str;
        default = "${escapeSystemdPath config.root}.mount";
      };
      rootDir = mkOption {
        type = path;
        internal = true;
      };
    };
  };
  mkMountType' = { rootDir, specialArgs, modules ? [ ] }: let
    rootDirModule = { ... }: {
      config.rootDir = mkOptionDefault rootDir;
    };
  in lib.types.submoduleWith {
    modules = [ mountModule rootDirModule ] ++ modules;
    inherit specialArgs;
  };
  mkMountType = args: with lib.types; coercedTo path (path: { path = mkOptionDefault path; }) (mkMountType' args);
  serviceModule = { config, nixosConfig, ... }: let
    cfg = config.gensokyo-zone;
    mapSharedMounts = f: mapAttrsToList (_: target:
      f target
    ) cfg.sharedMounts;
    mapCacheMounts = f: mapAttrsToList (_: target:
      f target
    ) cfg.cacheMounts;
    mkRequire = mount: mount.mountUnit;
    mkBindPath = mount: "${mount.source}:${mount.path}";
    specialArgs = {
      service = config;
      inherit nixosConfig;
    };
    mountUnits = mkMerge [
      (mkIf (cfg.sharedMounts != { }) (mapSharedMounts mkRequire))
      (mkIf (cfg.cacheMounts != { }) (mapCacheMounts mkRequire))
    ];
  in {
    options.gensokyo-zone = with lib.types; {
      sharedMounts = mkOption {
        type = attrsOf (mkMountType { rootDir = "/mnt/shared"; inherit specialArgs; });
        default = { };
      };
      cacheMounts = mkOption {
        type = attrsOf (mkMountType { rootDir = "/mnt/caches"; inherit specialArgs; });
        default = { };
      };
    };
    config = {
      requires = mountUnits;
      after = mountUnits;
      serviceConfig = mkMerge [
        (mkIf (cfg.sharedMounts != { }) {
          BindPaths = mapSharedMounts mkBindPath;
        })
        (mkIf (cfg.cacheMounts != { }) {
          BindPaths = mapCacheMounts mkBindPath;
        })
      ];
    };
  };
in {
  options = with lib.types; {
    systemd.services = mkOption {
      type = attrsOf (submoduleWith {
        modules = [ serviceModule ];
        shorthandOnlyDefinesConfig = true;
        specialArgs = {
          nixosConfig = config;
        };
      });
    };
  };
}
