{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkMerge;
  cfg = config.services.deluge;
in {
  options.services.deluge = with lib.types; {
    downloadDir = mkOption {
      type = path;
      default = cfg.dataDir + "/Downloads";
    };
    completedDir = mkOption {
      type = nullOr path;
      default = null;
    };
  };
  config = {
    services.deluge = {
      config = mkMerge [
        {
          download_location = cfg.downloadDir;
          move_completed = cfg.completedDir != null;
        }
        (mkIf (cfg.completedDir != null) {
          move_completed_path = cfg.completedDir;
        })
      ];
    };
  };
}
