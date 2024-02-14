{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services.steam) accountSwitch;
  cfg = config.services.steam.library;
in {
  options.services.steam.library = with lib.types; {
    setup = mkEnableOption "steam library data";
    group = mkOption {
      type = str;
      default = accountSwitch.group;
    };
    rootDir = mkOption {
      type = path;
    };
    steamappsDir = mkOption {
      type = path;
      default = cfg.rootDir + "/steamapps";
    };
  };

  config = {
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
      setupFiles = {
        ${cfg.rootDir} = toplevel;
        ${cfg.steamappsDir} = shared;
      };
    in {
      enable = mkIf cfg.setup true;
      files = mkIf cfg.setup setupFiles;
    };
  };
}
