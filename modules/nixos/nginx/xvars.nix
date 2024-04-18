let
  locationModule = { config, virtualHost, lib, ... }: let
    inherit (lib.options) mkEnableOption;
    cfg = config.xvars;
  in {
    options.xvars = with lib.types; {
      enable = mkEnableOption "$x_variables";
    };
    config = let
    in {
    };
  };
  hostModule = { config, nixosConfig, gensokyo-zone, xvars, lib, ... }: let
    inherit (gensokyo-zone.lib) mkJustBefore;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkMerge mkOptionDefault;
    inherit (lib.strings) concatStringsSep;
    inherit (lib.attrsets) attrValues filterAttrs mapAttrs mapAttrsToList;
    inherit (lib.lists) any;
    cfg = config.xvars;
    escapeString = value: if value == "" then ''""'' else value;
  in {
    options = with lib.types; {
      xvars = {
        enable = mkEnableOption "$x_variables";
        parseReferer = mkEnableOption "$x_referer_{scheme,host,path}";
        defaults = mkOption {
          type = attrsOf (nullOr str);
          default = rec {
            scheme = "$scheme";
            forwarded_for = remote_addr;
            remote_addr = "$remote_addr";
            forwarded_server = host;
            host = "$host";
            referer = "$http_referer";
            proxy_host = null;
            proxy_scheme = null;
          };
        };
        lib = mkOption {
          type = attrs;
        };
      };
      locations = mkOption {
        type = attrsOf (submoduleWith {
          modules = [ locationModule ];
          shorthandOnlyDefinesConfig = true;
          specialArgs = {
            inherit nixosConfig gensokyo-zone xvars;
            virtualHost = config;
          };
        });
      };
    };
    config = let
      defaults = concatStringsSep "\n" (mapAttrsToList (
        name: value: "set $x_${name} ${escapeString value};"
      ) (filterAttrs (_: value: value != null) cfg.defaults));
      parseReferer = ''
        if (${xvars.get.referer} ~ "^(https?)://([^/]*)(/.*)$") {
          ${xvars.init "referer_scheme" "$1"}
          ${xvars.init "referer_host" "$2"}
          ${xvars.init "referer_path" "$3"}
        }
      '';
    in {
      xvars = {
        enable = mkMerge [
          (mkIf (any (loc: loc.xvars.enable) (attrValues config.locations)) true)
          (mkIf cfg.parseReferer true)
        ];
        defaults = mkIf cfg.parseReferer (mkOptionDefault {
          referer_scheme = null;
          referer_host = null;
          referer_path = null;
        });
        lib = {
          get = mapAttrs (name: default: if cfg.enable then "$x_${name}" else assert default != null; default) cfg.defaults;
          init = name: value: assert cfg.enable && cfg.defaults ? ${name}; "set $x_${name} ${escapeString value};";
          inherit escapeString;
        };
      };
      extraConfig = mkMerge [
        (mkIf cfg.enable (mkJustBefore defaults))
        (mkIf (cfg.enable && cfg.parseReferer) (mkJustBefore parseReferer))
      ];
      _module.args.xvars = config.xvars.lib;
    };
  };
in {
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
        modules = [ hostModule ];
        shorthandOnlyDefinesConfig = true;
        specialArgs = {
          inherit gensokyo-zone;
          nixosConfig = config;
        };
      });
    };
  };
}
