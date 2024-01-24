{
  config,
  utils,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.lists) singleton;
  cfg = config.services.mediatomb;
  mediaDirModule = { config, ... }: {
    options = with lib.types; {
      mountPoint = mkOption {
        type = nullOr str;
        default = null;
      };
      subdirectories = mkOption {
        type = nullOr (listOf str);
        default = null;
      };
      paths = mkOption {
        type = listOf path;
      };
    };
    config = {
      paths = let
        paths = map (path: "${config.path}/${path}") config.subdirectories;
        path = singleton config.path;
      in mkOptionDefault (if config.subdirectories != null then paths else path);
      recursive = mkDefault true;
      hidden-files = mkDefault false;
    };
  };
in {
  options.services.mediatomb = with lib.types; {
    confine = mkEnableOption "containment" // {
      default = true;
    };
    mediaDirectories = mkOption {
      type = listOf (submodule mediaDirModule);
    };
  };

  config.services.mediatomb = {
    openFirewall = mkDefault true;
    serverName = mkDefault config.networking.hostName;
  };
  config.systemd.services.mediatomb = mkIf cfg.enable {
    confinement.enable = mkIf cfg.confine (mkDefault true);
    bindsTo = map (dir: mkIf (dir.mountPoint != null)
      "${utils.escapeSystemdPath dir.mountPoint}.mount"
    ) cfg.mediaDirectories;
    unitConfig.RequiresMountsFor = mkMerge (
      map (dir: dir.paths) cfg.mediaDirectories
    );
    serviceConfig = {
      RestartSec = mkDefault 15;
      StateDirectory = mkDefault cfg.package.pname;
      BindReadOnlyPaths = mkIf cfg.confine (mkMerge (
        map (dir: dir.paths) cfg.mediaDirectories
      ));
    };
  };
}
