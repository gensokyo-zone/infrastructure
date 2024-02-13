{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
in {
  options = with lib.types; {
    deploy.system = mkOption {
      type = unspecified;
      readOnly = true;
    };
  };
  config = {
    deploy.system = config.system.build.toplevel;
  };
}
