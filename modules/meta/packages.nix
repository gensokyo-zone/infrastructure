{
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.types) attrsOf package;
in {
  options.outputs.packages = mkOption {
    type = attrsOf package;
    default = { };
  };

  config.outputs.packages = {
    nf-deploy = pkgs.writeShellScriptBin "nf-deploy" ''
      exec ${pkgs.runtimeShell} ${../../ci/deploy.sh} "$@"
    '';
  };
}
