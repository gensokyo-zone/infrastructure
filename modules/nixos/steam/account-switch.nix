{
  config,
  lib,
  inputs,
  pkgs,
  ...
}: let
  inherit (inputs.self.lib.lib) userIs;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.attrsets) filterAttrs mapAttrsToList listToAttrs nameValuePair;
  inherit (lib.lists) singleton;
  cfg = config.services.steam.accountSwitch;
in {
  options.services.steam.accountSwitch = with lib.types; {
    enable = mkEnableOption "steam-account-switch";
    setup = mkEnableOption "steam-account-switch data";
    group = mkOption {
      type = str;
      default = "steamaccount";
    };
    sharePath = mkOption {
      type = str;
    };
    rootDir = mkOption {
      type = path;
    };
    binDir = mkOption {
      type = path;
      default = cfg.rootDir + "/bin";
    };
    gamesDir = mkOption {
      type = path;
      default = cfg.rootDir + "/games";
    };
    dataDir = mkOption {
      type = path;
      default = cfg.rootDir + "/data";
    };
    sharedDataDir = mkOption {
      type = path;
      default = cfg.dataDir + "/shared";
    };
    workingDir = mkOption {
      type = path;
      default = cfg.rootDir + "/working";
    };
    sharedWorkingDir = mkOption {
      type = path;
      default = cfg.workingDir + "/shared";
    };
    users = mkOption {
      type = listOf str;
    };
  };

  config = let
    steamUsers = filterAttrs (_: userIs cfg.group) config.users.users;
  in {
    services.steam.accountSwitch = {
      users = mkOptionDefault (
        mapAttrsToList (_: user: user.name) steamUsers
      );
    };
    services.tmpfiles = let
      toplevel = {
        owner = mkDefault "admin";
        group = mkDefault cfg.group;
        mode = mkDefault "3775";
      };
      shared = {
        inherit (toplevel) owner group;
        mode = "2775";
      };
      personal = owner: {
        inherit owner;
        inherit (shared) group mode;
      };
      setupFiles =
        singleton {
          ${cfg.rootDir} = toplevel;
          ${cfg.binDir} = toplevel;
          ${cfg.binDir + "/users"} = shared;
          ${cfg.dataDir} = toplevel;
          ${cfg.sharedDataDir} = shared;
          ${cfg.workingDir} = toplevel;
          ${cfg.sharedWorkingDir} = shared;
        }
        ++ map (owner: {
          ${cfg.dataDir + "/${owner}"} = personal owner;
          ${cfg.workingDir + "/${owner}"} = personal owner;
        })
        cfg.users;
      userBinFiles = listToAttrs (map (user:
        nameValuePair "${cfg.binDir}/users/${user}.bat" {
          inherit (toplevel) owner group;
          mode = "0755";
          type = "copy";
          src = pkgs.writeTextFile {
            name = "steam-${user}.bat";
            executable = true;
            text = ''
              setx GENSO_STEAM_USER ${user}
            '';
          };
        })
      cfg.users);
    in {
      enable = mkIf (cfg.enable || cfg.setup) true;
      files = mkMerge [
        (mkIf cfg.setup (mkMerge setupFiles))
        (mkIf cfg.enable userBinFiles)
      ];
    };
  };
}
