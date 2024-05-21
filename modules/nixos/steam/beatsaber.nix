{
  config,
  pkgs,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) userIs;
  inherit (config.lib.steam) mkSharePath;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.strings) hasSuffix replaceStrings optionalString concatStringsSep escapeShellArg makeBinPath versionOlder;
  inherit (lib.attrsets) attrValues filterAttrs mapAttrs mapAttrs' mapAttrsToList listToAttrs nameValuePair;
  inherit (lib.lists) concatLists head last filter sort singleton;
  inherit (config.services.steam) accountSwitch;
  cfg = config.services.steam.beatsaber;
  sortedVersions = sort (a: b: versionOlder a.version b.version) (attrValues cfg.versions);
  prevVersionFor = version: let
    olderVersions = filter (v: versionOlder v.version version) sortedVersions;
  in
    if olderVersions != []
    then last olderVersions
    else null;
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
      previousVersion = mkOption {
        type = nullOr str;
      };
      __toString = mkOption {
        type = functionTo str;
      };
    };
    config = {
      __toString = mkOptionDefault (
        config: config.version
      );
      previousVersion = mkOptionDefault (
        prevVersionFor config.version
      );
    };
  };
  fileModule = {
    config,
    name,
    ...
  }: {
    options = with lib.types; {
      relativePath = mkOption {
        type = str;
        default = name;
      };
      type = mkOption {
        type = enum ["file" "directory"];
        default = "file";
      };
      versioned = mkOption {
        type = bool;
        default = false;
      };
      target = mkOption {
        type = enum ["user" "shared" "game"];
        default = "user";
      };
      mode = {
        file = mkOption {
          type = str;
          default =
            if hasSuffix ".exe" config.relativePath || hasSuffix ".dll" config.relativePath
            then "775"
            else "664";
        };
        dir = mkOption {
          type = str;
          default = "2775";
        };
      };
      ownerFor = mkOption {
        type = functionTo str;
      };
      srcPathFor = mkOption {
        type = functionTo path;
      };
      srcStyle = mkOption {
        type = enum ["empty" "copy" "symlink" "symlink-shallow"];
        default = "symlink";
      };
      workingPathFor = mkOption {
        type = functionTo path;
      };
      init = mkOption {
        type = nullOr path;
      };
      initFor = mkOption {
        type = functionTo (nullOr path);
      };
      initStyle = mkOption {
        type = enum ["none" "copy" "symlink" "symlink-shallow"];
        default = "copy";
      };
      setup = {
        shared = mkOption {
          type = functionTo lines;
          internal = true;
        };
        script = mkOption {
          type = functionTo lines;
          internal = true;
        };
      };
    };
    config = let
      versionPathFor = version: optionalString config.versioned "/${version}";
    in {
      init = mkOptionDefault (
        if config.target == "game"
        then null
        else if config.type == "directory"
        then "${emptyDir}"
        else if hasSuffix ".json" config.relativePath
        then "${emptyJson}"
        else if hasSuffix ".dll" config.relativePath || hasSuffix ".exe" config.relativePath
        then "${emptyExecutable}"
        else "${emptyFile}"
      );
      initFor = mkOptionDefault (
        {
          user,
          version,
        }:
          config.init
      );
      ownerFor = mkOptionDefault (
        user:
          if config.target == "user"
          then user
          else "admin"
      );
      srcPathFor = mkOptionDefault (
        {
          user,
          version,
        }:
          {
            shared = cfg.sharedDataDir + versionPathFor version;
            user = cfg.dataDirFor user + versionPathFor version;
            game = cfg.gameDirFor version;
          }
          .${config.target}
          or (throw "unsupported target")
          + "/${config.relativePath}"
      );
      workingPathFor = mkOptionDefault (
        {
          user,
          version,
        }:
          cfg.workingDirFor {inherit user version;}
          + "/${config.relativePath}"
      );
      # TODO: setup.shared and do inits seperately!
      setup.script = {
        user,
        version,
      } @ args: let
        owner = config.ownerFor user;
        srcPath = config.srcPathFor args;
        workingPath = config.workingPathFor args;
        initPath = config.initFor args;
        parentWorkingPath = dirOf workingPath;
        mkdir = dest: ''
          if [[ -L ${escapeShellArg dest} ]]; then
            rm -f ${escapeShellArg dest}
          fi
          if [[ ! -d ${escapeShellArg dest} ]]; then
            mkdir -m${config.mode.dir} ${escapeShellArg dest}
          else
            chmod ${config.mode.dir} ${escapeShellArg dest}
          fi
          chown ${owner}:${cfg.group} ${escapeShellArg dest}
        '';
        mkStyle = {
          style,
          src,
        }:
          if
            style
            != "none"
            && src
            == {
              file = "${emptyFile}";
              directory = "${emptyDir}";
            }
            .${config.type}
          then "empty"
          else style;
        doInit = {
          style,
          src,
          dest,
        }:
          {
            none = "true";
            copy =
              {
                file = ''
                  if [[ -L ${escapeShellArg dest} ]]; then
                    rm -f ${escapeShellArg dest}
                  elif [[ -e ${escapeShellArg dest} ]]; then
                    echo ERR: something is in the way of copying ${escapeShellArg dest} >&2
                    exit 1
                  fi
                  cp -TP --no-preserve=all ${escapeShellArg src} ${escapeShellArg dest}
                  chmod ${config.mode.file} ${escapeShellArg dest}
                  chown ${owner}:${cfg.group} ${escapeShellArg dest}
                '';
                directory = ''
                  ${mkdir dest}
                  cp -rTP --no-preserve=all ${escapeShellArg src} ${escapeShellArg dest}
                  chown -R ${owner}:${cfg.group} ${escapeShellArg dest}
                  find ${escapeShellArg dest} -type f -exec chmod -m${config.mode.file} "{}" \;
                '';
              }
              .${config.type};
            empty =
              {
                directory = ''
                  ${mkdir dest}
                '';
                file = ''
                  touch ${escapeShellArg dest}
                  chmod ${config.mode.file} ${escapeShellArg dest}
                  chown ${owner}:${cfg.group} ${escapeShellArg dest}
                '';
              }
              .${config.type};
            symlink = ''
              if [[ -e ${escapeShellArg dest} && ! -L ${escapeShellArg dest} ]]; then
                echo ERR: something is in the way of linking ${escapeShellArg dest} >&2
                exit 1
              fi
              ln -sfT ${escapeShellArg src} ${escapeShellArg dest}
            '';
            symlink-shallow =
              {
                directory = ''
                  ${mkdir dest}
                  ln -sf ${escapeShellArg src}/* ${escapeShellArg dest}/
                '';
              }
              .${config.type};
          }
          .${mkStyle {inherit style src;}};
        doSetup = {
          style,
          src,
          dest,
        }:
          rec {
            none = "true";
            copy =
              {
                file = ''
                  ${empty}
                '';
                directory = ''
                  ${empty}
                  if [[ ${escapeShellArg dest}/* != ${escapeShellArg dest}/\* ]]; then
                    chmod -m${config.mode.file} ${escapeShellArg dest}/*
                  fi
                '';
              }
              .${config.type};
            empty =
              {
                directory = ''
                  chmod ${config.mode.dir} ${escapeShellArg dest}
                  chown ${owner}:${cfg.group} ${escapeShellArg dest}
                '';
                file = ''
                  chmod ${config.mode.file} ${escapeShellArg dest}
                  chown ${owner}:${cfg.group} ${escapeShellArg dest}
                '';
              }
              .${config.type};
            symlink = "true";
            symlink-shallow =
              {
                directory = ''
                  ${mkdir.directory}
                '';
              }
              .${config.type};
          }
          .${mkStyle {inherit style src;}};
        init = doInit {
          style = config.initStyle;
          src = initPath;
          dest = srcPath;
        };
        setup = doSetup {
          style = config.initStyle;
          src = initPath;
          dest = srcPath;
        };
        src = doInit {
          style = config.srcStyle;
          src = srcPath;
          dest = workingPath;
        };
        checkFlag =
          {
            file =
              {
                none = "e";
                copy = "f";
                symlink = "L";
              }
              .${config.initStyle};
            directory =
              {
                none = "e";
                copy = "d";
                symlink-shallow = "d";
                symlink = "L";
              }
              .${config.initStyle};
          }
          .${config.type};
        checkParent = ''
          if [[ ! -d ${escapeShellArg parentWorkingPath} ]]; then
            echo ERR: parent of ${escapeShellArg workingPath} does not exist >&2
            exit 1
          fi
        '';
        check =
          if initPath != null
          then ''
            if [[ ! -${checkFlag} ${escapeShellArg srcPath} ]]; then
              ${init}
            else
              ${setup}
            fi
          ''
          else ''
            if [[ ! -${checkFlag} ${escapeShellArg srcPath} ]]; then
              echo ERR: src ${escapeShellArg srcPath} for ${escapeShellArg workingPath} does not exist >&2
              exit 1
            fi
          '';
      in ''
        ${checkParent}
        ${check}
        ${src}
      '';
    };
  };
  userModule = {
    config,
    name,
    ...
  }: {
    options = with lib.types; {
      name = mkOption {
        type = str;
        default = name;
      };
      preferredVersion = mkOption {
        type = str;
        default = cfg.defaultVersion;
      };
    };
  };
  emptyFile = pkgs.writeText "empty.txt" "";
  emptyJson = pkgs.writeText "empty.json" "{}";
  emptyDir = pkgs.runCommand "empty" {} ''
    mkdir $out
  '';
  emptyExecutable = pkgs.writeTextFile {
    name = "empty.exe";
    executable = true;
    text = "";
  };

  bsdata = "Beat Saber_Data";

  vars = let
    bsUserData = mkSharePath (cfg.dataDirFor "%GENSO_STEAM_USER%");
    bsWorkingData = mkSharePath (cfg.workingDirFor {
      user = "%GENSO_STEAM_USER%";
      version = "%GENSO_STEAM_BS_VERSION%";
    });
  in ''
    if "%GENSO_STEAM_MACHINE%" == "" set "GENSO_STEAM_MACHINE=%COMPUTERNAME%"
    if "%GENSO_STEAM_LOCAL_DATA%" == "" set "GENSO_STEAM_LOCAL_DATA=C:\Program Files\GensokyoZone"
    if "%GENSO_STEAM_LOCAL_DATA_BS%" == "" set "GENSO_STEAM_LOCAL_DATA_BS=%GENSO_STEAM_LOCAL_DATA%\${cfg.dirName}"
    if "%GENSO_STEAM_INSTALL%" == "" set "GENSO_STEAM_INSTALL=C:\Program Files (x86)\Steam"
    if "%GENSO_STEAM_LIBRARY_BS%" == "" set "GENSO_STEAM_LIBRARY_BS=%GENSO_STEAM_INSTALL%"
    if "%GENSO_STEAM_BS_VERSION%" == "" set "GENSO_STEAM_BS_VERSION=${cfg.defaultVersion}"
    if "%GENSO_SMB_HOST%" == "" set "GENSO_SMB_HOST=smb.${config.networking.domain}"
    if "%GENSO_SMB_SHARED_MOUNT%" == "" set "GENSO_SMB_SHARED_MOUNT=\\%GENSO_SMB_HOST%\shared"
    set "STEAM_BS_LIBRARY=%GENSO_STEAM_LIBRARY_BS%\steamapps\common\Beat Saber"
    set "STEAM_BS_APPDATA=%USERPROFILE%\AppData\LocalLow\Hyperbolic Magnetism\Beat Saber"
    set "STEAM_BS_LOCAL_DATA=%GENSO_STEAM_LOCAL_DATA_BS%\%GENSO_STEAM_BS_VERSION%"
    set "STEAM_BS_USER_DATA=${bsUserData}"
    set "STEAM_BS_WORKING_DATA=${bsWorkingData}"
    if "%GENSO_STEAM_BS_LOCAL%" == "1" (
      set "STEAM_BS_LAUNCH=%STEAM_BS_LOCAL_DATA%"
      set "STEAM_BS_LAUNCH_APPDATA=%STEAM_BS_LOCAL_DATA%\AppData"
    ) else (
      set "STEAM_BS_LAUNCH=%STEAM_BS_WORKING_DATA%"
      set "STEAM_BS_LAUNCH_APPDATA=%STEAM_BS_USER_DATA%\AppData"
    )
    if "%GENSO_STEAM_USER%" == "" goto NOUSER
  '';
  eof = ''
    goto:eof

    :NOUSER
    echo no steam user set
  '';
  mount = ''
    rmdir "%STEAM_BS_APPDATA%"
    mklink /D "%STEAM_BS_APPDATA%" "%STEAM_BS_LAUNCH_APPDATA%"

    rmdir "%STEAM_BS_LIBRARY%"
    mklink /D "%STEAM_BS_LIBRARY%" "%STEAM_BS_LAUNCH%"
  '';
  launch =
    ''
      cd /d "%STEAM_BS_LIBRARY%"
    ''
    + ''"%STEAM_BS_LIBRARY%\Beat Saber.exe"'';
  setup = ''
    rmdir "%STEAM_BS_APPDATA%"
    rmdir "%STEAM_BS_LIBRARY%"

    mkdir "%GENSO_STEAM_LOCAL_DATA_BS%"
    move /Y "%STEAM_BS_LIBRARY%" "%GENSO_STEAM_LOCAL_DATA_BS%\Vanilla"
    move /Y "%STEAM_BS_APPDATA%" "%GENSO_STEAM_LOCAL_DATA_BS%\Vanilla\AppData"
  '';
  mountbeatsaber = ''
    ${vars}
    ${mount}
    ${eof}
  '';
  launchbeatsaber = ''
    ${vars}
    ${mount}
    ${launch}
    ${eof}
  '';
  fpfcbeatsaber = ''
    ${vars}
    ${launch} fpfc
    ${eof}
  '';
  setupbeatsaber = ''
    ${vars}
    ${setup}
    pause
    ${eof}
  '';
  localbeatsaber-mount = ''
    set GENSO_STEAM_BS_LOCAL=1
    ${vars}
    ${mount}
    if NOT "%GENSO_STEAM_BS_VERSION%" == "Vanilla" (
      rmdir "%STEAM_BS_LIBRARY%\UserData"
      mklink /D "%STEAM_BS_LIBRARY%\UserData" "%STEAM_BS_WORKING_DATA%\UserData"
    )
    ${eof}
  '';
  localbeatsaber-vanilla = ''
    set GENSO_STEAM_BS_VERSION=Vanilla
    set GENSO_STEAM_BS_LOCAL=1
    ${vars}
    ${mount}
    ${eof}
  '';
  localbeatsaber-launch = ''
    set GENSO_STEAM_BS_LOCAL=1
    ${vars}
    ${mount}
    ${launch}
    ${eof}
  '';
  beatsaber-user = {
    user,
    version,
  }: ''
    set GENSO_STEAM_USER=${user}
    set GENSO_STEAM_BS_VERSION=${version}
    ${vars}
    ${mount}
    ${launch}
    ${eof}
  '';
  vanilla = ''
    setx GENSO_STEAM_BS_VERSION Vanilla
  '';

  mksetupbeatsaber = {
    user,
    version,
  }: let
    setupFiles = mapAttrsToList (_: file: file.setup.script {inherit user version;}) cfg.files;
  in
    pkgs.writeShellScript "setupbeatsaber-${user}-${version}" ''
      set -eu
      export PATH="$PATH:${makeBinPath [pkgs.coreutils]}"
      ${concatStringsSep "\n" setupFiles}
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
    setupServiceNames = mkOption {
      type = listOf str;
      readOnly = true;
    };
    files = mkOption {
      type = attrsOf (submodule fileModule);
      default = {};
    };
    users = mkOption {
      type = attrsOf (submodule userModule);
    };
    dirName = mkOption {
      type = str;
      default = "BeatSaber";
    };
    binDir = mkOption {
      type = path;
      default = accountSwitch.binDir + "/beatsaber";
    };
    gamesDir = mkOption {
      type = path;
      default = accountSwitch.gamesDir + "/${cfg.dirName}";
    };
    gameDirFor = mkOption {
      type = functionTo path;
      default = version: cfg.gamesDir + "/${version}";
    };
    sharedDataDir = mkOption {
      type = path;
      default = accountSwitch.sharedDataDir + "/${cfg.dirName}";
    };
    userDataDir = mkOption {
      type = path;
      default = accountSwitch.dataDir;
    };
    dataDirFor = mkOption {
      type = functionTo path;
      default = user: cfg.userDataDir + "/${user}/${cfg.dirName}";
    };
    userWorkingDir = mkOption {
      type = path;
      default = accountSwitch.workingDir;
    };
    userWorkingDirFor = mkOption {
      type = functionTo path;
      default = user: cfg.userWorkingDir + "/${user}/${cfg.dirName}";
    };
    workingDirFor = mkOption {
      type = functionTo path;
      default = {
        user,
        version,
      }:
        cfg.userWorkingDirFor user + "/${version}";
    };
  };

  config = {
    services.steam.beatsaber = let
      bsUsers = filterAttrs (_: userIs cfg.group) config.users.users;
      allVersions = mapAttrsToList (_: version: version.version) cfg.versions;
      gameFiles = {
        "Beat Saber.exe" = {};
        "UnityCrashHandler64.exe" = {};
        "UnityPlayer.dll" = {};
        "MonoBleedingEdge".type = "directory";
      };
      sharedFiles = {
        DynamicOpenVR = {
          type = "directory";
          versioned = true;
        };
        IPA = {
          type = "directory";
          versioned = true;
        };
        Libs = {
          type = "directory";
          versioned = true;
        };
        Plugins = {
          type = "directory";
          versioned = true;
        };
        Logs = {
          type = "directory";
          versioned = true;
        };
        "BeatSaberVersion.txt" = {
          versioned = true;
          initFor = {version, ...}: pkgs.writeText "BeatSaberVersion-${version}.txt" version;
        };
        "IPA.exe".versioned = true;
        "IPA.exe.config".versioned = true;
        "IPA.runtimeconfig.json".versioned = true;
        "winhttp.dll".versioned = true;
        ${bsdata} = {
          type = "directory";
          versioned = true;
          #initStyle = "symlink-shallow";
          #initFor = { version, ... }: cfg.gameDirFor version + "/${bsdata}";
          initStyle = "none";
          srcPathFor = {version, ...}: cfg.gameDirFor version + "/${bsdata}";
          srcStyle = "symlink-shallow";
        };
        "${bsdata}/Managed" = {
          type = "directory";
          versioned = true;
          initFor = {version, ...}: cfg.gameDirFor version + "/${bsdata}/Managed";
        };
        # TODO: remove this to use multiple folders
        "${bsdata}/CustomLevels" = {
          type = "directory";
          initStyle = "none";
          srcPathFor = {...}: cfg.sharedDataDir + "/CustomLevels";
        };
        CustomAvatars = {
          type = "directory";
          initStyle = "none";
        };
        CustomNotes = {
          type = "directory";
          initStyle = "none";
        };
        CustomPlatforms = {
          type = "directory";
          initStyle = "none";
        };
        CustomSabers = {
          type = "directory";
          initStyle = "none";
        };
        CustomWalls = {
          type = "directory";
          initStyle = "none";
        };
        Playlists = {
          type = "directory";
          initStyle = "none";
        };
        "UserData/ScoreSaber/Replays" = {
          type = "directory";
          initStyle = "none";
          srcPathFor = {...}: cfg.sharedDataDir + "/Replays";
        };
        "UserData/Beat Saber IPA.json".versioned = true;
        "UserData/SongCore/" = {
          versioned = true;
          relativePath = "UserData/SongCore";
          type = "directory";
          srcStyle = "empty";
        };
        "UserData/SongCore/folders.xml" = {
          versioned = true;
        };
        "UserData/SongCore/SongCoreExtraData.dat" = {
          versioned = true;
          init = "${emptyJson}";
        };
        "UserData/SongCore/SongDurationCache.dat" = {
          versioned = true;
          init = "${emptyJson}";
        };
        "UserData/SongCore/SongHashData.dat" = {
          versioned = true;
          init = "${emptyJson}";
        };
        "UserData/Chroma".type = "directory";
        "UserData/Nya".type = "directory";
        "UserData/SongRankedBadge".type = "directory";
        "UserData/DrinkWater".type = "directory";
        "UserData/Enhancements".type = "directory";
        "UserData/HitScoreVisualizer" = {
          type = "directory";
          # TODO: initStyle = "symlink"; init = "${myhitscorejsons}";
        };
        "UserData/Saber Factory/" = {
          relativePath = "UserData/Saber Factory";
          type = "directory";
          srcStyle = "empty";
        };
        "UserData/Saber Factory/Cache".type = "directory";
        "UserData/Saber Factory/Textures".type = "directory";
        "UserData/BeatSaverDownloader.ini" = {};
        "UserData/BeatSaverUpdater.json" = {};
        "UserData/SongDetailsCache.proto".versioned = true;
        "UserData/SongDetailsCache.proto.Direct.etag".versioned = true;
      };
      userFiles = {
        "UserData" = {
          type = "directory";
          versioned = true;
          srcStyle = "empty";
        };
        "UserData/Camera2".type = "directory";
        "UserData/Saber Factory" = {
          type = "directory";
          srcStyle = "empty";
        };
        "UserData/Saber Factory/Presets".type = "directory";
        "UserData/Saber Factory/TrailConfig.json" = {};
        "UserData/SongCore" = {
          type = "directory";
          versioned = true;
          srcStyle = "empty";
        };
        "UserData/SongCore/SongCore.json" = {
          versioned = true;
        };
        "UserData/ScoreSaber" = {
          type = "directory";
          versioned = true;
          srcStyle = "empty";
        };
        "UserData/ScoreSaber/ScoreSaber.json" = {
          versioned = true;
        };
        "UserData/Disabled Mods.json".versioned = true;
        "UserData/modprefs.ini".versioned = true;
        "UserData/JDFixer.json".versioned = true;
      };
      userDataFiles = [
        "modprefs.ini"
        "Disabled Mods.json"
        "AutoPauseStealth.json"
        "BeatSaberMarkupLanguage.json"
        "BeatSaviorData.ini"
        "BetterSongList.json"
        "BetterSongSearch.json"
        "bookmarkedSongs.json"
        "votedSongs.json"
        "Chroma.json"
        "Cinema.json"
        "CountersPlus.json"
        "CustomAvatars.CalibrationData.dat"
        "CustomAvatars.json"
        "CustomNotes.json"
        "Custom Platforms.json"
        "CustomWalls.json"
        "DrinkWater.json"
        "EasyOffset.json"
        "Enhancements.json"
        "FasterScroll.json"
        "FastFail.json"
        "Fifth Anniversary Mod.json"
        "Gotta Go Fast.json"
        "Heck.json"
        "HitScoreVisualizer.json"
        "HitsoundTweaks.json"
        "Intro Skip.json"
        "JDFixer.json"
        "ModelDownloader.json"
        "Music Spatializer.json"
        "Nya.json"
        "ParticleOverdrive.ini"
        "PerformanceMeter.json"
        "PlayFirst.json"
        "PlaylistManager.json"
        "PracticePlugin.json"
        "Saber Factory.json"
        "SaberTailor.json"
        "ScorePercentage.json"
        "SiraUtil.json"
        "SmoothCamPlus.json"
        "SongChartVisualizer.json"
        "SongPlayData.json"
        "SongPlayHistory.json"
        "SongRankedBadge.json"
        "Technicolor.json"
        "Tweaks55.json"
        "UITweaks.json"
      ];
      mapSharedFile = file:
        file
        // {
          target = "shared";
        };
      mapGameFile = file:
        file
        // {
          target = "game";
        };
      mapUserDataFile = file:
        nameValuePair "UserData/${file}" {
          target = "user";
        };
    in {
      defaultVersion = mkIf (allVersions != []) (mkOptionDefault (
        head allVersions
      ));
      users = mapAttrs (_: user: {name = mkDefault user.name;}) bsUsers;
      setupServiceNames = mkOptionDefault (
        mapAttrsToList (_: user: "steam-setup-beatsaber-${user.name}.service") cfg.users
      );
      files = mkMerge [
        userFiles
        (listToAttrs (map mapUserDataFile userDataFiles))
        (mapAttrs (_: mapGameFile) gameFiles)
        (mapAttrs (_: mapSharedFile) sharedFiles)
      ];
    };
    systemd.services.steam-setup-beatsaber = mkIf cfg.setup {
      wantedBy = [
        "multi-user.target"
      ];
      after = [
        "tmpfiles.service"
      ];
      serviceConfig = {
        Type = mkOptionDefault "oneshot";
        RemainAfterExit = mkOptionDefault true;
        ExecStart = mkMerge (mapAttrsToList (
            _: user: (mapAttrsToList (
                _: version: "${mksetupbeatsaber {
                  user = user.name;
                  inherit (version) version;
                }}"
              )
              cfg.versions)
          )
          cfg.users);
      };
    };
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
        "Playlists"
        "Replays"
        "AppData"
        "UserData"
      ];
      setupFiles =
        [
          {
            ${cfg.sharedDataDir} = toplevel;
            ${cfg.binDir} = shared;
          }
          (listToAttrs (
            map (
              folder:
                nameValuePair "${cfg.sharedDataDir}/${folder}" shared
            )
            sharedFolders
          ))
        ]
        ++ concatLists (mapAttrsToList (
            _: user:
              singleton {
                ${cfg.dataDirFor user.name} = personal user.name;
                "${cfg.dataDirFor user.name}/AppData" = personal user.name;
                "${cfg.dataDirFor user.name}/UserData" = personal user.name;
              }
              ++ mapAttrsToList (_: version: {
                "${cfg.dataDirFor user.name}/${version.version}" = personal user.name;
                ${cfg.userWorkingDirFor user.name} = personal user.name;
                ${
                  cfg.workingDirFor {
                    user = user.name;
                    inherit (version) version;
                  }
                } =
                  personal user.name;
              })
              cfg.versions
          )
          cfg.users)
        ++ mapAttrsToList (_: version: {
          "${cfg.sharedDataDir}/${version.version}" = shared;
        })
        cfg.versions;
      versionBinFiles =
        mapAttrs' (
          _: version:
            nameValuePair
            "${cfg.binDir}/${replaceStrings ["."] ["_"] version.version}.bat"
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
      userBinFiles =
        mapAttrs' (
          _: user:
            nameValuePair
            "${cfg.binDir}/${user.name}.bat"
            {
              inherit (bin) owner group mode type;
              src = pkgs.writeTextFile {
                name = "beatsaber-${user.name}.bat";
                executable = true;
                text = beatsaber-user {
                  user = user.name;
                  version = user.preferredVersion;
                };
              };
            }
        )
        cfg.users;
      binFiles =
        {
          "${cfg.binDir}/mount.bat" = {
            inherit (bin) owner group mode type;
            src = pkgs.writeTextFile {
              name = "beatsaber-mount.bat";
              executable = true;
              text = mountbeatsaber;
            };
          };
          "${cfg.binDir}/launch.bat" = {
            inherit (bin) owner group mode type;
            src = pkgs.writeTextFile {
              name = "beatsaber-launch.bat";
              executable = true;
              text = launchbeatsaber;
            };
          };
          "${cfg.binDir}/fpfc.bat" = {
            inherit (bin) owner group mode type;
            src = pkgs.writeTextFile {
              name = "beatsaber-fpfc.bat";
              executable = true;
              text = fpfcbeatsaber;
            };
          };
          "${cfg.binDir}/setup.bat" = {
            inherit (bin) owner group mode type;
            src = pkgs.writeTextFile {
              name = "beatsaber-setup.bat";
              executable = true;
              text = setupbeatsaber;
            };
          };
          "${cfg.binDir}/local-launch.bat" = {
            inherit (bin) owner group mode type;
            src = pkgs.writeTextFile {
              name = "beatsaber-local-launch.bat";
              executable = true;
              text = localbeatsaber-launch;
            };
          };
          "${cfg.binDir}/local-mount.bat" = {
            inherit (bin) owner group mode type;
            src = pkgs.writeTextFile {
              name = "beatsaber-local-mount.bat";
              executable = true;
              text = localbeatsaber-mount;
            };
          };
          "${cfg.binDir}/local-vanilla.bat" = {
            inherit (bin) owner group mode type;
            src = pkgs.writeTextFile {
              name = "beatsaber-local-vanilla.bat";
              executable = true;
              text = localbeatsaber-vanilla;
            };
          };
          "${cfg.binDir}/vanilla.bat" = {
            inherit (bin) owner group mode type;
            src = pkgs.writeTextFile {
              name = "beatsaber-version-vanilla.bat";
              executable = true;
              text = vanilla;
            };
          };
          "${cfg.binDir}/ModAssistant.exe" = {
            inherit (bin) owner group mode type;
            src = pkgs.fetchurl {
              url = "https://github.com/Assistant/ModAssistant/releases/download/v1.1.32/ModAssistant.exe";
              hash = "sha256-ozu2gYFiz+2BjptqL80DmUopbahbyGKFO1IPd7BhVPM=";
              executable = true;
            };
          };
        }
        // versionBinFiles
        // userBinFiles;
    in {
      enable = mkIf cfg.setup true;
      files = mkIf cfg.setup (mkMerge (
        singleton binFiles
        ++ setupFiles
      ));
    };
  };
}
