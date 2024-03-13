{
  config,
  pkgs,
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib.lib) mkWinPath userIs;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.strings) removePrefix replaceStrings;
  inherit (lib.attrsets) filterAttrs mapAttrs' mapAttrsToList listToAttrs nameValuePair;
  inherit (lib.lists) concatMap head singleton;
  inherit (lib.meta) getExe;
  inherit (config.services.steam) accountSwitch;
  cfg = config.services.steam.beatsaber;
  versionModule = {
    config,
    name,
    ...
  }: {
    options = with lib.types; {
      version = mkOption {
        type = str;
        default = name;
      };
    };
  };

  mkSharePath = path:
    mkWinPath (
      "%GENSO_SMB_SHARED_MOUNT%"
      + "/${accountSwitch.sharePath}"
      + "/${removePrefix (accountSwitch.rootDir + "/") path}"
    );
  vars = ''
    if "%GENSO_STEAM_INSTALL%" == "" set "GENSO_STEAM_INSTALL=C:\Program Files (x86)\Steam"
    if "%GENSO_STEAM_LIBRARY_BS%" == "" set "GENSO_STEAM_LIBRARY_BS=%GENSO_STEAM_INSTALL%"
    if "%GENSO_STEAM_BS_VERSION%" == "" set "GENSO_STEAM_BS_VERSION=${cfg.defaultVersion}"
    if "%GENSO_SMB_HOST%" == "" set "GENSO_SMB_HOST=smb.${config.networking.domain}"
    if "%GENSO_SMB_SHARED_MOUNT%" == "" set "GENSO_SMB_SHARED_MOUNT=\\%GENSO_SMB_HOST%\shared"
    set "STEAM_BS_LIBRARY=%GENSO_STEAM_LIBRARY_BS%\steamapps\common\Beat Saber"
    set "STEAM_BS_APPDATA=%USERPROFILE%\AppData\LocalLow\Hyperbolic Magnetism\Beat Saber"
    set "STEAM_USER_DATA=${mkSharePath accountSwitch.dataDir}\%GENSO_STEAM_USER%"
    set "STEAM_WORKING_DATA=${mkSharePath accountSwitch.workingDir}\%GENSO_STEAM_USER%"
    set "STEAM_BINDIR=${mkSharePath accountSwitch.binDir}"
    if "%GENSO_STEAM_USER%" == "" goto NOUSER
  '';
  eof = ''
    goto:eof

    :NOUSER
    echo no steam user set
  '';
  mount = ''
    rmdir "%STEAM_BS_APPDATA%"
    mklink /D "%STEAM_BS_APPDATA%" "%STEAM_USER_DATA%\BeatSaber\AppData"

    rmdir "%STEAM_BS_LIBRARY%"
    mklink /D "%STEAM_BS_LIBRARY%" "%STEAM_WORKING_DATA%\BeatSaber\%GENSO_STEAM_BS_VERSION%"
  '';
  mountbeatsaber = ''
    ${vars}
    ${mount}
    ${eof}
  '';
  launchbeatsaber = ''
    ${vars}
    ${mount}
    cd /d "%STEAM_BS_LIBRARY%"
    "%STEAM_BS_LIBRARY%\Beat Saber.exe"
    ${eof}
  '';
  fpfcbeatsaber = ''
    ${vars}
    ${mount}
    cd /d "%STEAM_BS_LIBRARY%"
    "%STEAM_BS_LIBRARY%\Beat Saber.exe" fpfc
    ${eof}
  '';

  mkbeatsabersh = pkgs.writeShellScriptBin "mkbeatsaber.sh" ''
    source ${./mkbeatsaber.sh}
  '';
  mkbeatsaber = pkgs.writeShellScriptBin "mkbeatsaber" ''
    set -eu

    ARG_GAME_VERSION=$1
    shift
    if [[ $# -gt 0 ]]; then
      ARG_USER=$1
      shift
    else
      ARG_USER=$(${pkgs.coreutils}/bin/id -un)
    fi

    cd ${accountSwitch.workingDir}
    mkdir -m2775 -p "$ARG_USER/BeatSaber/$ARG_GAME_VERSION"
    chown "$ARG_USER" "$ARG_USER" "$ARG_USER/BeatSaber"
    cd "$ARG_USER/BeatSaber/$ARG_GAME_VERSION"
    ${getExe mkbeatsabersh} \
      "${accountSwitch.gamesDir}/BeatSaber" \
      "$ARG_GAME_VERSION" \
      "${accountSwitch.sharedDataDir}/BeatSaber" \
      "${accountSwitch.dataDir}/$ARG_USER/BeatSaber"
  '';
in {
  options.services.steam.beatsaber = with lib.types; {
    enable = mkEnableOption "beatsaber scripts";
    setup =
      mkEnableOption "beatsaber data"
      // {
        default = accountSwitch.setup;
      };
    group = mkOption {
      type = str;
      default = "beatsaber";
    };
    defaultVersion = mkOption {
      type = str;
    };
    versions = mkOption {
      type = attrsOf (submodule versionModule);
      default = {};
    };
    users = mkOption {
      type = listOf str;
    };
  };

  config = let
  in {
    services.steam.beatsaber = let
      bsUsers = filterAttrs (_: userIs cfg.group) config.users.users;
      allVersions = mapAttrsToList (_: version: version.version) cfg.versions;
    in {
      defaultVersion = mkIf (allVersions != []) (mkOptionDefault (
        head allVersions
      ));
      users = mkOptionDefault (
        mapAttrsToList (_: user: user.name) bsUsers
      );
    };
    environment = mkIf cfg.enable {
      systemPackages = [
        mkbeatsaber
        mkbeatsabersh
      ];
    };
    systemd.services = mkIf cfg.setup (listToAttrs (map (user:
      nameValuePair "steam-setup-beatsaber-${user}" {
        script = mkMerge (mapAttrsToList (_: version: ''
            ${getExe mkbeatsaber} ${version.version} ${user}
          '')
          cfg.versions);
        path = [
          pkgs.coreutils
        ];
        wantedBy = [
          "multi-user.target"
        ];
        after = [
          "tmpfiles.service"
        ];
        serviceConfig = {
          RemainAfterExit = mkOptionDefault true;
          User = mkOptionDefault user;
        };
      })
    cfg.users));
    services.tmpfiles = let
      toplevel = {
        owner = mkDefault "admin";
        group = mkDefault cfg.group;
        mode = mkDefault "3775";
      };
      shared = {
        inherit (toplevel) owner group;
        mode = mkDefault "2775";
      };
      personal = owner: {
        inherit owner;
        inherit (shared) group mode;
      };
      bin = {
        inherit (toplevel) owner group;
        mode = "0755";
        type = "copy";
      };
      sharedFolders = [
        "CustomAvatars"
        "CustomLevels"
        "CustomNotes"
        "CustomPlatforms"
        "CustomSabers"
        "CustomWalls"
        "AppData"
        "UserData"
      ];
      setupFiles =
        [
          {
            "${accountSwitch.sharedDataDir}/BeatSaber" = toplevel;
            "${accountSwitch.binDir}/beatsaber" = shared;
          }
          (listToAttrs (
            map (
              folder:
                nameValuePair "${accountSwitch.sharedDataDir}/BeatSaber/${folder}" shared
            )
            sharedFolders
          ))
        ]
        ++ concatMap (
          owner:
            singleton {
              "${accountSwitch.dataDir}/${owner}/BeatSaber" = personal owner;
              "${accountSwitch.dataDir}/${owner}/BeatSaber/AppData" = personal owner;
              "${accountSwitch.dataDir}/${owner}/BeatSaber/UserData" = personal owner;
            }
            ++ mapAttrsToList (_: version: {
              "${accountSwitch.dataDir}/${owner}/BeatSaber/${version.version}" = personal owner;
            })
            cfg.versions
        )
        accountSwitch.users
        ++ mapAttrsToList (_: version: {
          "${accountSwitch.sharedDataDir}/BeatSaber/${version.version}" = shared;
        })
        cfg.versions;
      versionBinFiles =
        mapAttrs' (
          _: version:
            nameValuePair
            "${accountSwitch.binDir}/beatsaber/${replaceStrings ["."] ["_"] version.version}.bat"
            {
              inherit (bin) owner group mode type;
              src = pkgs.writeTextFile {
                name = "beatsaber-${version.version}.bat";
                executable = true;
                text = ''
                  setx GENSO_STEAM_BS_VERSION ${version.version}
                '';
              };
            }
        )
        cfg.versions;
      binFiles =
        {
          "${accountSwitch.binDir}/beatsaber/mount.bat" = {
            inherit (bin) owner group mode type;
            src = pkgs.writeTextFile {
              name = "beatsaber-mount.bat";
              executable = true;
              text = mountbeatsaber;
            };
          };
          "${accountSwitch.binDir}/beatsaber/launch.bat" = {
            inherit (bin) owner group mode type;
            src = pkgs.writeTextFile {
              name = "beatsaber-launch.bat";
              executable = true;
              text = launchbeatsaber;
            };
          };
          "${accountSwitch.binDir}/beatsaber/fpfc.bat" = {
            inherit (bin) owner group mode type;
            src = pkgs.writeTextFile {
              name = "beatsaber-fpfc.bat";
              executable = true;
              text = fpfcbeatsaber;
            };
          };
          "${accountSwitch.binDir}/beatsaber/ModAssistant.exe" = {
            inherit (toplevel) owner group;
            mode = "0755";
            type = "copy";
            src = pkgs.fetchurl {
              url = "https://github.com/Assistant/ModAssistant/releases/download/v1.1.32/ModAssistant.exe";
              hash = "sha256-ozu2gYFiz+2BjptqL80DmUopbahbyGKFO1IPd7BhVPM=";
              executable = true;
            };
          };
        }
        // versionBinFiles;
    in {
      enable = mkIf (cfg.enable || cfg.setup) true;
      files = mkMerge [
        (mkIf cfg.setup (mkMerge setupFiles))
        (mkIf cfg.enable binFiles)
      ];
    };
  };
}
