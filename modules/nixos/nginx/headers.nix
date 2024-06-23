let
  locationModule = {
    config,
    virtualHost,
    xvars,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mapOptionDefaults;
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkIf mkMerge mkAfter mkOptionDefault;
    inherit (lib.attrsets) mapAttrsToList mapAttrs;
    inherit (lib.lists) isList;
    cfg = config.headers;
  in {
    options.headers = with lib.types; {
      inheritServerDefaults = mkOption {
        type = bool;
        default = true;
      };
      set = mkOption {
        type = attrsOf (nullOr (oneOf [str (listOf str)]));
      };
    };
    config = let
      mkHeader = name: value:
        if isList value
        then mkMerge (map (mkHeader name) value)
        else mkAfter "add_header ${name} ${xvars.escapeString value};";
      setHeaders = mapAttrsToList (name: value: mkIf (value != null) (mkHeader name value)) cfg.set;
    in {
      headers = {
        set = mkMerge [
          (mkOptionDefault {})
          (mkIf cfg.inheritServerDefaults (mapOptionDefaults virtualHost.headers.set))
        ];
      };
      proxy.headers.hide = mkIf (cfg.set != {}) (mapAttrs (_: value: mkOptionDefault (value != null)) cfg.set);
      extraConfig = mkMerge setHeaders;
    };
  };
  hostModule = {
    config,
    nixosConfig,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mapOptionDefaults;
    inherit (lib.options) mkOption;
    inherit (nixosConfig.services) nginx;
  in {
    options = with lib.types; {
      headers = {
        set = mkOption {
          type = attrsOf (nullOr (oneOf [str (listOf str)]));
        };
      };
      locations = mkOption {
        type = attrsOf (submoduleWith {
          modules = [locationModule];
          shorthandOnlyDefinesConfig = true;
        });
      };
    };
    config = {
      headers = {
        set = mapOptionDefaults nginx.headers.set;
      };
    };
  };
in
  {lib, ...}: let
    inherit (lib.options) mkOption;
  in {
    options.services.nginx = with lib.types; {
      headers = {
        set = mkOption {
          type = attrsOf (nullOr (oneOf [str (listOf str)]));
          default = {
          };
        };
      };
      virtualHosts = mkOption {
        type = attrsOf (submodule [hostModule]);
      };
    };
  }
