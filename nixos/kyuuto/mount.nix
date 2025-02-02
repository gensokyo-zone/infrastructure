{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.strings) removePrefix;
  inherit (lib.attrsets) listToAttrs nameValuePair;
  inherit (config.services.steam) accountSwitch beatsaber;
  cfg = config.kyuuto;
  mapId = id:
    if config.proxmoxLXC.privileged or true
    then 100000 + id
    else id;
in {
  options.kyuuto = with lib.types; {
    setup = mkEnableOption "directory and permission setup";
    mountDir = mkOption {
      type = path;
      default = "/mnt/kyuuto-media";
    };
    shareDir = mkOption {
      type = path;
      default = cfg.mountDir + "/shared";
    };
    transferDir = mkOption {
      type = path;
      default = cfg.mountDir + "/transfer";
    };
    libraryDir = mkOption {
      type = path;
      default = cfg.mountDir + "/library";
    };
    downloadsDir = mkOption {
      type = path;
      default = cfg.mountDir + "/downloads";
    };
    gameLibraryDir = mkOption {
      type = path;
      default = cfg.libraryDir + "/games";
    };
    dataDir = mkOption {
      type = path;
      default = "/mnt/kyuuto-data";
    };
    gameLibraries = mkOption {
      type = listOf str;
      default = ["PC"];
    };
  };

  config = {
    kyuuto = {
      gameLibraries = [
        "PC"
        "Wii"
        "Gamecube"
        "N64"
        "SNES"
        "NES"
        "NDS"
        "GBA"
        "GBC"
        "PS3"
        "PS2"
        "PS1"
        "PSVita"
        "PSP"
        "Genesis"
      ];
    };
    services.steam = {
      library = {
        setup = mkDefault cfg.setup;
        rootDir = cfg.shareDir + "/steam/library";
      };
      accountSwitch = {
        setup = mkDefault cfg.setup;
        sharePath = removePrefix "${cfg.shareDir}/" accountSwitch.rootDir;
        rootDir = cfg.shareDir + "/steam";
      };
    };
    services.tmpfiles = let
      shared = {
        owner = mkDefault "admin";
        group = mkDefault "kyuuto";
        mode = mkDefault "3775";
      };
      share = mkMerge [
        shared
        {group = "peeps";}
      ];
      leaf = {
        inherit (shared) owner group;
        mode = mkDefault "2775";
      };
      deluge = rec {
        inherit (leaf) mode;
        owner = toString (mapId 83); # deluge uid
        group = owner;
      };
      setupFiles = [
        {
          ${cfg.shareDir} = share;
          ${cfg.shareDir + "/projects"} = share;
          ${cfg.transferDir} = shared;
          ${cfg.libraryDir} = shared;
          ${cfg.libraryDir + "/unsorted"} = shared;
          ${cfg.libraryDir + "/music"} = shared;
          ${cfg.libraryDir + "/music/assorted"} = leaf;
          ${cfg.libraryDir + "/music/collections"} = shared;
          ${cfg.libraryDir + "/anime"} = leaf;
          ${cfg.libraryDir + "/tv"} = leaf;
          ${cfg.libraryDir + "/movies"} = leaf;
          ${cfg.libraryDir + "/software"} = leaf;
          ${cfg.libraryDir + "/books"} = leaf;
          ${cfg.downloadsDir} = shared;
          ${cfg.downloadsDir + "/deluge"} = deluge;
          ${cfg.downloadsDir + "/deluge/download"} =
            deluge
            // {
              group = "kyuuto";
              mode = mkDefault "2755";
            };
          ${cfg.dataDir + "/minecraft/simplebackups"} =
            leaf
            // {
              owner = toString (mapId 913); # minecraft-bedrock uid
              group = "admin";
            };
          ${cfg.gameLibraryDir} = shared;
        }
        (listToAttrs (
          map (gameLibrary: nameValuePair (cfg.gameLibraryDir + "/${gameLibrary}") leaf) cfg.gameLibraries
        ))
      ];
    in {
      enable = mkIf cfg.setup true;
      files = mkMerge [
        (mkIf cfg.setup (mkMerge setupFiles))
        (mkIf (accountSwitch.enable || beatsaber.setup) {
          ${accountSwitch.gamesDir} = {
            type = "bind";
            bindReadOnly = true;
            src = cfg.gameLibraryDir + "/PC";
            systemd.mountSettings = rec {
              wantedBy = mkIf beatsaber.setup beatsaber.setupServiceNames;
              before = wantedBy;
            };
          };
        })
      ];
    };

    users = let
      mkDummyUsers = {
        name,
        group ? name,
        enable ? !config.services.${serviceName}.enable,
        serviceName ? name,
        uid ? config.ids.uids.${name},
        gid ? config.ids.gids.${group},
      }:
        mkIf enable {
          users.${name} = {
            group = mkIf (group != null) group;
            uid = mapId uid;
            isSystemUser = true;
          };
          groups.${group} = {
            gid = mapId gid;
          };
        };
    in
      mkMerge [
        (mkDummyUsers {name = "deluge";})
        (mkDummyUsers {name = "radarr";})
        (mkDummyUsers {name = "sonarr";})
        (mkDummyUsers {name = "lidarr";})
      ];
  };
}
