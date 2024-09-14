{
  pkgs,
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mapListToAttrs mkAlmostOptionDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkAfter mkOptionDefault;
  inherit (lib.attrsets) nameValuePair;
  inherit (lib.strings) concatMapStrings escapeShellArg;
  cfg = config.services.klipper;
  includeFileName = "00-includes.cfg";
  includeFile = pkgs.writeText "klipper-includes.cfg" (concatMapStrings (
      path: "[include ${path}]\n"
    )
    cfg.configFiles);
  mkIncludeSetting = path: nameValuePair "include ${path}" (mkOptionDefault {});
  includeSettings = mapListToAttrs mkIncludeSetting (
    if cfg.mutableConfig
    then [includeFileName]
    else cfg.configFiles
  );
in {
  options.services.klipper = with lib.types; {
    quiet = mkEnableOption "more silent logs";
    logRotate = mkEnableOption "logrotate";
    configFiles = mkOption {
      type = listOf path;
      default = [];
    };
  };
  config.services.klipper = {
    settings = mkMerge [
      (mkIf (cfg.configFiles != []) includeSettings)
      {
        virtual_sdcard = mkIf cfg.mutableConfig {
          path = mkOptionDefault "${cfg.mutableConfigFolder}/gcodes";
        };
      }
    ];
  };
  config.systemd.services.klipper = mkIf cfg.enable {
    serviceConfig = mkIf cfg.quiet {
      LogFilterPatterns = [
        ''~INFO:root:Stats''
        ''~INFO:root:toolhead''
        ''~max_accel:''
        ''~minimum_cruise_ratio:''
        ''~square_corner_velocity:''
      ];
    };
    preStart = mkIf (cfg.configFiles != [] && cfg.mutableConfig) (mkAfter ''
      ln -sfT ${includeFile} ${escapeShellArg "${cfg.mutableConfigFolder}/${includeFileName}"}
    '');
  };
  config.services.logrotate.settings.klipper = mkIf (cfg.enable && cfg.logRotate && cfg.logFile != null) {
    files = mkAlmostOptionDefault cfg.logFile;
  };
}
