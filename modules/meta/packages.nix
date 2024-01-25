{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.types) attrsOf package;
  inherit (lib.meta) getExe;
  inherit (lib.strings) concatStringsSep concatMapStringsSep;
  cfg = config.outputs.packages;
  fmt = import ../../ci/fmt.nix;
in {
  options.outputs.packages = mkOption {
    type = attrsOf package;
    default = { };
  };

  config.outputs.packages = {
    inherit (pkgs.buildPackages)
      terraform tflint
      alejandra deadnix statix
    ;
    nf-deploy = pkgs.writeShellScriptBin "nf-deploy" ''
      exec ${pkgs.runtimeShell} ${../../ci/deploy.sh} "$@"
    '';
    nf-statix = pkgs.writeShellScriptBin "nf-statix" ''
      if [[ $# -eq 0 ]]; then
        set -- check
      fi

      if [[ ''${1-} = check ]]; then
        shift
        set -- check --config ${../../ci/statix.toml} "$@"
      fi

      exec ${getExe cfg.statix} "$@"
    '';
    nf-deadnix = let
      inherit (fmt.nix) blacklistDirs;
      excludes = "${getExe pkgs.buildPackages.findutils} ${concatStringsSep " " blacklistDirs} -type f";
    in pkgs.writeShellScriptBin "nf-deadnix" ''
      exec ${getExe cfg.deadnix} "$@" \
        --no-lambda-arg \
        --exclude $(${excludes})
    '';
    nf-alejandra = let
      inherit (fmt.nix) blacklistDirs;
      excludes = concatMapStringsSep " " (dir: "--exclude ${dir}") blacklistDirs;
    in pkgs.writeShellScriptBin "nf-alejandra" ''
      exec ${getExe cfg.alejandra} \
        ${excludes} \
        "$@"
    '';
    nf-lint-tf = pkgs.writeShellScriptBin "nf-lint-tf" ''
      ${getExe cfg.terraform} fmt "$@" &&
      ${cfg.tflint}/bin/tflint
    '';
    nf-lint-nix = pkgs.writeShellScriptBin "nf-lint-nix" ''
      ${getExe cfg.nf-statix} check "$@" &&
      ${getExe cfg.nf-deadnix} -f "$@"
    '';
    nf-fmt-nix = let
      inherit (fmt.nix) whitelist;
      includes = concatStringsSep " " whitelist;
    in pkgs.writeShellScriptBin "nf-fmt-nix" ''
      exec ${getExe cfg.nf-alejandra} ${includes} "$@"
    '';
  };
}
