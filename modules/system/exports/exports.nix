{
  config,
  name,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  cfg = config.exports;
  systemConfig = config;
  exportModule = {
    config,
    name,
    ...
  }: {
    options = with lib.types; {
      enable = mkEnableOption "exported service";
      name = mkOption {
        type = str;
        default = name;
      };
      serviceName = mkOption {
        type = str;
        default = name;
      };
      id = mkOption {
        type = str;
        default =
          cfg.services.${config.serviceName}.id
          /*
          or config.name
          */
          ;
      };
    };
  };
in {
  options.exports = with lib.types; {
    exports = mkOption {
      type = attrsOf (submoduleWith {
        modules = [exportModule];
        specialArgs = {
          machine = name;
          inherit systemConfig;
        };
      });
      default = {};
    };
  };

  config = {
    _module.args.exports = cfg;
  };
}
