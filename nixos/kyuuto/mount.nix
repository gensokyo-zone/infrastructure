{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.strings) match concatStringsSep;
  inherit (lib.lists) optional;
  cfg = config.kyuuto;
in {
  options.kyuuto = with lib.types; {
    setup = mkEnableOption "directory and permission setup";
    mountDir = mkOption {
      type = path;
      default = "/mnt/kyuuto-media";
    };
    libraryDir = mkOption {
      type = path;
      default = cfg.mountDir + "/library";
    };
    transferDir = mkOption {
      type = path;
      default = cfg.mountDir + "/transfer";
    };
    shareDir = mkOption {
      type = path;
      default = cfg.mountDir + "/shared";
    };
  };

  config = {
    systemd.tmpfiles.rules = let
      isGroupWritable = mode: match "[375][0-7][76][0-7]" mode != null;
      isOtherWritable = mode: match "[375][0-7][0-7][76]" mode != null;
      mkKyuutoDir = {
        path,
        mode ? "3775",
        owner ? "guest",
        group ? "kyuuto",
        acls ? optional (isGroupWritable mode) "default:group::rwx"
          ++ optional (isOtherWritable mode) "default:other::rwx",
      }: [
        "d ${path} ${mode} ${owner} ${group}"
      ] ++ optional (acls != [ ]) "a+ ${path} - - - - ${concatStringsSep "," acls}";
    in mkIf cfg.setup (
      mkKyuutoDir { path = cfg.transferDir; }
      ++ mkKyuutoDir { path = cfg.shareDir; owner = "root"; }
      ++ mkKyuutoDir { path = cfg.libraryDir; owner = "root"; }
      ++ mkKyuutoDir { path = cfg.libraryDir + "/unsorted"; }
      ++ mkKyuutoDir { path = cfg.libraryDir + "/music"; owner = "root"; }
      ++ mkKyuutoDir { path = cfg.libraryDir + "/music/assorted"; owner = "sonarr"; mode = "7775"; }
      ++ mkKyuutoDir { path = cfg.libraryDir + "/music/collections"; }
      ++ mkKyuutoDir { path = cfg.libraryDir + "/anime"; owner = "sonarr"; mode = "7775"; }
      ++ mkKyuutoDir { path = cfg.libraryDir + "/tv"; owner = "sonarr"; mode = "7775"; }
      ++ mkKyuutoDir { path = cfg.libraryDir + "/movies"; owner = "radarr"; mode = "7775"; }
      ++ mkKyuutoDir { path = cfg.libraryDir + "/software"; }
      ++ mkKyuutoDir { path = cfg.libraryDir + "/books"; }
      ++ mkKyuutoDir { path = cfg.libraryDir + "/games"; }
    );

    users = let
      mapId = id: if config.proxmoxLXC.privileged or true then 100000 + id else id;
      mkDummyUsers = {
        name,
        group ? name,
        enable ? !config.services.${serviceName}.enable, serviceName ? name,
        uid ? config.ids.uids.${name},
        gid ? config.ids.gids.${group},
      }: mkIf enable {
        users.${name} = {
          group = mkIf (group != null) group;
          uid = mapId uid;
          isSystemUser = true;
        };
        groups.${group} = {
          gid = mapId gid;
        };
      };
    in mkMerge [
      (mkDummyUsers { name = "deluge"; })
      (mkDummyUsers { name = "radarr"; })
      (mkDummyUsers { name = "sonarr"; })
      (mkDummyUsers { name = "lidarr"; })
    ];
  };
}
