let
  locationModule = {
    config,
    virtualHost,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mkJustBefore;
    inherit (lib.options) mkEnableOption mkOption;
    inherit (lib.modules) mkIf;
    inherit (lib.attrsets) mapAttrs mapAttrsToList filterAttrs;
    inherit (lib.strings) concatStringsSep;
    cfg = config.xvars;
    defaultValues = filterAttrs (name: value: value != null && value != virtualHost.xvars.defaults.${name} or null) cfg.defaults;
    defaults = concatStringsSep "\n" (mapAttrsToList (
        name: value: "set $x_${name} ${virtualHost.xvars.lib.escapeString value};"
      )
      defaultValues);
  in {
    options.xvars = with lib.types; {
      enable = mkEnableOption "$x_variables";
      defaults = mkOption {
        type = attrsOf (nullOr str);
        default = {};
      };
      lib = mkOption {
        type = attrs;
      };
    };
    config = {
      xvars = {
        lib = let
          xvars = virtualHost.xvars.lib;
          get = mapAttrs (name: default:
            if virtualHost.xvars.enable
            then "$x_${name}"
            else assert default != null; default)
          cfg.defaults;
        in
          xvars
          // {
            get = xvars.get // get;
          };
      };
      extraConfig = mkIf (cfg.enable && defaultValues != {}) (mkJustBefore defaults);
      _module.args.xvars = config.xvars.lib;
    };
  };
  hostModule = {
    config,
    nixosConfig,
    gensokyo-zone,
    xvars,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mkJustBefore mapOptionDefaults;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkMerge;
    inherit (lib.attrsets) attrValues filterAttrs mapAttrs mapAttrsToList;
    inherit (lib.lists) any;
    inherit (lib.strings) concatStringsSep hasPrefix hasInfix;
    inherit (lib.trivial) isInt;
    cfg = config.xvars;
    escapeString = value:
      if value == ""
      then ''""''
      else if isInt value
      then toString value
      else if hasPrefix ''"'' value || hasPrefix "'" value
      then value # already escaped, may include trailing arguments
      else if hasInfix ''"'' value
      then "'${value}'"
      else if hasInfix " " value || hasInfix ";" value || hasInfix "'" value
      then ''"${value}"''
      else value;
    anyLocations = f: any (loc: loc.enable && f loc) (attrValues config.locations);
  in {
    options = with lib.types; {
      xvars = {
        enable = mkEnableOption "$x_variables";
        parseReferer = mkEnableOption "$x_referer_{scheme,host,path}";
        defaults = mkOption {
          type = attrsOf (nullOr str);
        };
        lib = mkOption {
          type = attrs;
        };
      };
      locations = mkOption {
        type = attrsOf (submoduleWith {
          modules = [locationModule];
          shorthandOnlyDefinesConfig = true;
          specialArgs = {
            inherit nixosConfig gensokyo-zone;
            virtualHost = config;
          };
        });
      };
    };
    config = let
      defaultValues = filterAttrs (_: value: value != null) cfg.defaults;
      defaults = concatStringsSep "\n" (mapAttrsToList (
          name: value: "set $x_${name} ${escapeString value};"
        )
        defaultValues);
      parseReferer = ''
        set $hack_referer $http_referer;
        if ($hack_referer ~ "^(https?)://([^/]+)(/.*)$") {
          ${xvars.init "referer_scheme" "$1"}
          ${xvars.init "referer_host" "$2"}
          ${xvars.init "referer_path" "$3"}
        }
      '';
    in {
      xvars = {
        enable = mkMerge [
          (mkIf (anyLocations (loc: loc.xvars.enable)) true)
          (mkIf cfg.parseReferer true)
        ];
        defaults = mkMerge [
          (mapOptionDefaults rec {
            scheme = "$scheme";
            forwarded_for = remote_addr;
            remote_addr = "$remote_addr";
            forwarded_server = host;
            host = "$host";
            referer = "$http_referer";
            https = "$https";
          })
          (mkIf cfg.parseReferer (mapOptionDefaults {
            referer_scheme = null;
            referer_host = null;
            referer_path = null;
          }))
        ];
        lib = {
          get = mapAttrs (name: default:
            if cfg.enable
            then "$x_${name}"
            else assert default != null; default)
          cfg.defaults;
          init = name: value: assert cfg.enable && cfg.defaults ? ${name}; "set $x_${name} ${escapeString value};";
          inherit escapeString;
        };
      };
      extraConfig = mkMerge [
        (mkIf (cfg.enable && defaultValues != {}) (mkJustBefore defaults))
        (mkIf (cfg.enable && cfg.parseReferer) (mkJustBefore parseReferer))
      ];
      _module.args.xvars = config.xvars.lib;
    };
  };
in
  {
    config,
    lib,
    gensokyo-zone,
    ...
  }: let
    inherit (lib.options) mkOption;
  in {
    options = with lib.types; {
      services.nginx.virtualHosts = mkOption {
        type = attrsOf (submoduleWith {
          modules = [hostModule];
          shorthandOnlyDefinesConfig = true;
          specialArgs = {
            inherit gensokyo-zone;
            nixosConfig = config;
          };
        });
      };
    };
  }
