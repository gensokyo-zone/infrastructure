let
  cameraModule = {
    pkgs,
    config,
    gensokyo-zone,
    name,
    lib,
    lib'motion,
    ...
  }: let
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkMerge mkOptionDefault;
    inherit (lib.strings) hasPrefix;
  in {
    options = with lib.types; {
      enable = mkEnableOption "camera" // {
        default = true;
      };
      settings = mkOption {
        type = attrsOf (oneOf [str int bool]);
        description = "https://motion-project.github.io/motion_config.html";
      };
      extraConfig = mkOption {
        type = lines;
        default = "";
      };
      configText = mkOption {
        type = lines;
        internal = true;
      };
      configFile = mkOption {
        type = path;
      };
    };
    config = let
      configFile = pkgs.writeText "motion.conf" config.configText;
    in {
      settings = {
        videodevice = mkIf (hasPrefix "/" name) (mkOptionDefault name);
      };
      configFile = mkOptionDefault "${configFile}";
      configText = mkMerge (
        (lib'motion.mkMotionSettings config.settings)
        ++ [config.extraConfig]
      );
    };
  };
in {
  pkgs,
  config,
  gensokyo-zone,
  utils,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkPackageOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkAfter mkOptionDefault;
  inherit (lib.attrsets) attrValues mapAttrsToList;
  inherit (lib.lists) filter;
  inherit (lib.meta) getExe;
  cfg = config.services.motion;
  lib'motion = config.lib.motion;
in {
  options.services.motion = with lib.types; {
    enable = mkEnableOption "motion";
    package = mkPackageOption pkgs "motion" {};
    cameras = mkOption {
      type = attrsOf (submoduleWith {
        modules = [ cameraModule ];
        specialArgs = {
          inherit pkgs gensokyo-zone lib'motion;
          nixosConfig = config;
        };
      });
    };
    dataDir = mkOption {
      type = path;
      default = "/var/lib/motion";
    };
    user = mkOption {
      type = str;
      default = "motion";
    };
    group = mkOption {
      type = str;
      default = "motion";
    };
    settings = mkOption {
      type = attrsOf (oneOf [str int bool]);
      description = "https://motion-project.github.io/motion_config.html";
    };
    extraArgs = mkOption {
      type = listOf str;
      default = [];
    };
    extraConfig = mkOption {
      type = lines;
      default = "";
    };
    configText = mkOption {
      type = lines;
      internal = true;
    };
    configFile = mkOption {
      type = path;
    };
  };
  config.services.motion = let
    configFile = pkgs.writeText "motion.conf" cfg.configText;
    enableIPv6 = mkIf config.networking.enableIPv6 (mkOptionDefault true);
    enabledCameras = filter (camera: camera.enable) (attrValues cfg.cameras);
  in {
    settings = {
      target_dir = mkOptionDefault cfg.dataDir;
      ipv6_enabled = enableIPv6;
      webcontrol_ipv6 = enableIPv6;
    };
    configFile = mkOptionDefault "${configFile}";
    configText = mkMerge (
      (lib'motion.mkMotionSettings cfg.settings)
      ++ [cfg.extraConfig]
      ++ map (camera: mkAfter "camera ${camera.configFile}") enabledCameras
    );
  };
  config.users = mkIf cfg.enable {
    users.motion = {
      uid = 916;
      group = "motion";
      home = cfg.dataDir;
      extraGroups = ["video"];
    };
    groups.motion = {
      gid = config.users.users.motion.uid;
    };
  };
  config.systemd.services.motion = let
    cliArgs =
      [
        (getExe cfg.package)
        "-n"
        "-c"
        cfg.configFile
      ]
      ++ cfg.extraArgs;
  in
    mkIf cfg.enable {
      wantedBy = ["multi-user.target"];
      after = ["network.target"];
      serviceConfig = {
        Type = mkOptionDefault "exec";
        Restart = mkOptionDefault "on-failure";
        User = mkOptionDefault cfg.user;
        Group = mkOptionDefault cfg.group;
        ExecStart = [
          (utils.escapeSystemdExecArgs cliArgs)
        ];
      };
    };
  config.lib.motion = {
    mkMotionValue = value:
      if value == true
      then "on"
      else if value == false
      then "off"
      else toString value;
    mkMotionSetting = key: value: "${key} ${lib'motion.mkMotionValue value}";
    mkMotionSettings = mapAttrsToList lib'motion.mkMotionSetting;
  };
}
