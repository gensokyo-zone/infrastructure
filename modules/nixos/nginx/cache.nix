let
  locationModule = {
    config,
    virtualHost,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkIf mkMerge mkOptionDefault;
    inherit (lib.strings) hasPrefix removePrefix;
    cfg = config.cache;
  in {
    options.cache = with lib.types; {
      rootETag = mkOption {
        type = bool;
      };
    };
    config = let
      rootStoreDir = removePrefix "${builtins.storeDir}/" config.root;
    in {
      cache = {
        rootETag = mkOptionDefault (config.root != null && hasPrefix builtins.storeDir "${config.root}");
      };
      extraConfig = let
        # TODO: should use ${rootStoreDir} or strip store prefix from $request_filename
        rootETag = ''
          etag off;
          add_header etag '"$request_filename"';
        '';
      in
        mkMerge [
          (mkIf (cfg.rootETag && config.root != null) rootETag)
        ];
    };
  };
  hostModule = {
    config,
    lib,
    ...
  }: let
    inherit (lib.options) mkOption;
  in {
    # TODO: config.root exists too!
    options = with lib.types; {
      locations = mkOption {
        type = attrsOf (submoduleWith {
          modules = [locationModule];
          shorthandOnlyDefinesConfig = true;
        });
      };
    };
  };
in
  {lib, ...}: let
    inherit (lib.options) mkOption;
  in {
    options.services.nginx = with lib.types; {
      virtualHosts = mkOption {
        type = attrsOf (submodule [hostModule]);
      };
    };
  }
