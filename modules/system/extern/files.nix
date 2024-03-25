{config, lib, ...}: let
  inherit (lib.options) mkOption;
  fileModule = {config, name, ...}: {
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
    };
  };
in {
  options.extern = with lib.types; {
    files = mkOption {
      type = attrsOf (submodule fileModule);
      default = { };
    };
  };
}
