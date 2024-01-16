{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.types) attrsOf package;
  inherit (lib.meta) getExe;
  cfg = config.outputs.packages;
in {
  options.outputs.packages = mkOption {
    type = attrsOf package;
    default = { };
  };

  config.outputs.packages = {
    inherit (pkgs.buildPackages) terraform tflint;
    nf-deploy = pkgs.writeShellScriptBin "nf-deploy" ''
      exec ${pkgs.runtimeShell} ${../../ci/deploy.sh} "$@"
    '';
    nf-lint-tf = pkgs.writeShellScriptBin "nf-lint-tf" ''
      ${getExe cfg.terraform} fmt "$@" &&
      ${cfg.tflint}/bin/tflint
    '';
  };
}
