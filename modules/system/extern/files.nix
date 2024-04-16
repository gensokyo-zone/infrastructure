let
  fileModule = {config, name, gensokyo-zone, lib, ...}: let
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkOptionDefault;
    inherit (lib.strings) hasPrefix removePrefix;
  in {
    options = with lib.types; {
      path = mkOption {
        type = str;
        default = name;
      };
      owner = mkOption {
        type = str;
        default = "root";
      };
      group = mkOption {
        type = str;
        default = "root";
      };
      mode = mkOption {
        type = str;
        default = "0644";
      };
      source = mkOption {
        type = path;
      };
      relativeSource = mkOption {
        type = nullOr str;
      };
    };
    config = {
      relativeSource = let
        flakeRoot = toString gensokyo-zone.self + "/";
        sourcePath = toString config.source;
      in mkOptionDefault (
        if hasPrefix flakeRoot sourcePath then removePrefix flakeRoot sourcePath
        else null
      );
    };
  };
in {config, gensokyo-zone, lib, ...}: let
  inherit (lib.options) mkOption;
in {
  options.extern = with lib.types; {
    files = mkOption {
      type = attrsOf (submoduleWith {
        modules = [ fileModule ];
        specialArgs = {
          inherit gensokyo-zone;
          system = config;
        };
      });
      default = { };
    };
  };
}
