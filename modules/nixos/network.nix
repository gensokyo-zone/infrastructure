{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options.deploy.system = mkOption {
    type = types.unspecified;
    readOnly = true;
  };
  config = {
    deploy.system = config.system.build.toplevel;
  };
}
