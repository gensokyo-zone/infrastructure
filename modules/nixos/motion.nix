{
  pkgs,
  config,
  gensokyo-zone,
  utils,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mapOptionDefaults;
  inherit (lib.options) mkOption mkPackageOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkAfter mkOptionDefault;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.meta) getExe;
  cfg = config.services.motion;
  mkMotionValue = value:
    if value == true
    then "on"
    else if value == false
    then "off"
    else toString value;
  mkMotionSetting = key: value: "${key} ${mkMotionValue value}";
in {
  options.services.motion = with lib.types; {
    enable = mkEnableOption "motion";
    package = mkPackageOption pkgs "motion" {};
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
      description = "https://linux.die.net/man/1/motion";
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
  in {
    settings = mapOptionDefaults {
      target_dir = cfg.dataDir;
    };
    configFile = mkOptionDefault "${configFile}";
    configText = mkMerge (
      (mapAttrsToList mkMotionSetting cfg.settings)
      ++ [(mkAfter cfg.extraConfig)]
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
}
