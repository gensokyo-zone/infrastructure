{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge;
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
  };

  config = {
    systemd.tmpfiles.rules = mkIf cfg.setup [
      "d ${cfg.transferDir} 3775 guest kyuuto"
      "d ${cfg.libraryDir} 3775 kat kyuuto"
      "d ${cfg.libraryDir}/unsorted 3775 guest kyuuto"
      "d ${cfg.libraryDir}/music 7775 sonarr kyuuto"
      "d ${cfg.libraryDir}/anime 7775 sonarr kyuuto"
      "d ${cfg.libraryDir}/tv 7775 sonarr kyuuto"
      "d ${cfg.libraryDir}/movies 7775 radarr kyuuto"
    ];

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
