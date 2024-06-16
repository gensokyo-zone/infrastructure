let
  locationModule = {
    config,
    virtualHost,
    lib,
    ...
  }: {
    options = with lib.types; {
      /*
      accessLog = mkOption {
        type = submoduleWith {
          modules = [accessLogModule accessLogDefaults];
        };
      };
      */
    };
  };
  hostModule = {
    config,
    nixosConfig,
    xvars,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mapAlmostOptionDefaults;
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkIf;
    inherit (nixosConfig.services) nginx;
    cfg = config.accessLog;
    accessLogDefaults = _: {
      config = mapAlmostOptionDefaults {
        inherit (nginx.accessLog) enable path format;
      };
    };
  in {
    options = with lib.types; {
      accessLog = mkOption {
        type = submoduleWith {
          modules = [accessLogModule accessLogDefaults];
        };
        default = {};
      };
      locations = mkOption {
        type = attrsOf (submoduleWith {
          modules = [locationModule];
          shorthandOnlyDefinesConfig = true;
        });
      };
    };
    config = {
      extraConfig = mkIf cfg.emit cfg.directive;
    };
  };
  accessLogModule = {
    config,
    lib,
    ...
  }: let
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkOptionDefault;
    defaultPath = "/var/log/nginx/access.log";
    defaultFormat = "combined";
  in {
    options = with lib.types; {
      enable =
        mkEnableOption "access_log"
        // {
          default = true;
        };
      path = mkOption {
        type = str;
        default = defaultPath;
      };
      format = mkOption {
        type = str;
        default = defaultFormat;
      };
      directive = mkOption {
        type = str;
      };
      emit = mkOption {
        internal = true;
        type = bool;
      };
    };
    config = let
      isDefault = config.enable && config.path == defaultPath && config.format == defaultFormat;
      directive =
        if config.enable
        then "access_log ${config.path} ${config.format};"
        else "access_log off;";
    in {
      emit = mkOptionDefault (!isDefault);
      directive = mkOptionDefault directive;
    };
  };
in
  {
    config,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkIf mkAfter;
    inherit (config.services) nginx;
    cfg = nginx.accessLog;
    accessLogService = _: {
      config.emit = mkAlmostOptionDefault false;
    };
  in {
    options.services.nginx = with lib.types; {
      accessLog = mkOption {
        type = submoduleWith {
          modules = [
            accessLogModule
            accessLogService
          ];
        };
        default = {};
      };
      virtualHosts = mkOption {
        type = attrsOf (submodule [hostModule]);
      };
    };
    config.services.nginx = {
      commonHttpConfig = mkIf cfg.emit (mkAfter cfg.directive);
      virtualHosts.localhost = mkIf nginx.statusPage {
        # nixos module already sets `extraConfig = "access_log off;"`
        accessLog = {
          enable = false;
          emit = false;
        };
      };
    };
  }
