{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (config) kyuuto;
  cfg = kyuuto.opl;
in {
  options.kyuuto.opl = with lib.types; {
    enable =
      mkEnableOption "hosting"
      // {
        default = config.services.samba.enable;
      };
    user = mkOption {
      type = str;
      default = "opl";
    };
    rootDir = mkOption {
      type = path;
      default = kyuuto.mountDir + "/opl";
    };
    dvdDir = mkOption {
      type = path;
      default = cfg.rootDir + "/DVD";
    };
    gameLibraryDir = mkOption {
      type = path;
      default = kyuuto.gameLibraryDir + "/PS2";
    };
  };

  config = {
    services.samba = {
      settings' = mkIf cfg.enable {
        "ntlm auth" = mkDefault "ntlmv1-permitted";
        "server min protocol" = mkDefault "NT1";
        "keepalive" = mkDefault 0;
      };
      shares.opl = let
        inherit (config.networking.access) cidrForNetwork;
      in
        mkIf cfg.enable {
          comment = "Kyuuto Media OPL";
          path = cfg.rootDir;
          writeable = true;
          browseable = true;
          public = false;
          "valid users" = [
            cfg.user
            "@kyuuto-peeps"
          ];
          "strict sync" = false;
          "hosts allow" = cidrForNetwork.allLocal.all;
        };
    };
    services.tmpfiles = let
      setupFiles = {
        ${cfg.rootDir} = {
          owner = cfg.user;
          group = mkDefault "kyuuto";
          mode = mkDefault "2775";
        };
        ${cfg.dvdDir} = {
          type = mkDefault "directory";
          owner = mkDefault "admin";
          group = mkDefault "kyuuto";
          mode = mkDefault "2775";
        };
        "${cfg.rootDir}/games.bin" = {
          type = "copy";
          owner = cfg.user;
          group = mkDefault "kyuuto";
          mode = "0775";
          src = pkgs.writeText "empty" "";
          noOverwrite = true;
        };
        "${cfg.gameLibraryDir}/games.bin" = {
          type = "symlink";
          src = cfg.rootDir + "/games.bin";
          owner = mkDefault "admin";
          group = mkDefault "kyuuto";
        };
      };
      files = {
        ${cfg.dvdDir} = {
          type = "bind";
          src = cfg.gameLibraryDir;
          bindReadOnly = true;
        };
      };
    in {
      enable = mkIf (kyuuto.setup || cfg.enable) true;
      files = mkMerge [
        (mkIf kyuuto.setup setupFiles)
        (mkIf cfg.enable files)
      ];
    };
  };
}
