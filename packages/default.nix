{
  system,
  inputs,
  lib,
}: let
  inherit (lib.meta) getExe;
  inherit (lib.strings) concatStringsSep concatMapStringsSep;
  packages = inputs.self.packages.${system};
  inherit (inputs.self.legacyPackages.${system}) pkgs;
  fmt = import ../ci/fmt.nix;
  output = {
    inherit (pkgs.buildPackages)
      terraform tflint
      alejandra deadnix statix
    ;
    inherit (inputs.deploy-rs.packages.${system}) deploy-rs;
    nf-deploy = pkgs.writeShellScriptBin "nf-deploy" ''
      exec ${pkgs.runtimeShell} ${../ci/deploy.sh} "$@"
    '';
    nf-setup-reisen = let
      bin = ../../systems/reisen/bin;
    in pkgs.writeShellScriptBin "nf-setup-reisen" ''
      ssh root@reisen env \
        INPUT_INFRA_SETUP="$(base64 -w0 < ${bin + "/setup.sh"})" \
        INPUT_INFRA_PUTFILE64="$(base64 -w0 < ${bin + "/putfile64.sh"})" \
        INPUT_INFRA_PVE="$(base64 -w0 < ${bin + "/pve.sh"})" \
        INPUT_INFRA_LXC_CONFIG="$(base64 -w0 < ${bin + "/lxc-config.sh"})" \
        "bash -c \"eval \\\"\\\$(base64 -d <<<\\\$INPUT_INFRA_SETUP)\\\"\""
    '';
    nf-statix = pkgs.writeShellScriptBin "nf-statix" ''
      if [[ $# -eq 0 ]]; then
        set -- check
      fi

      if [[ ''${1-} = check ]]; then
        shift
        set -- check --config ${../ci/statix.toml} "$@"
      fi

      exec ${getExe packages.statix} "$@"
    '';
    nf-deadnix = let
      inherit (fmt.nix) blacklistDirs;
      excludes = "${getExe pkgs.buildPackages.findutils} ${concatStringsSep " " blacklistDirs} -type f";
    in pkgs.writeShellScriptBin "nf-deadnix" ''
      exec ${getExe packages.deadnix} "$@" \
        --no-lambda-arg \
        --exclude $(${excludes})
    '';
    nf-alejandra = let
      inherit (fmt.nix) blacklistDirs;
      excludes = concatMapStringsSep " " (dir: "--exclude ${dir}") blacklistDirs;
    in pkgs.writeShellScriptBin "nf-alejandra" ''
      exec ${getExe packages.alejandra} \
        ${excludes} \
        "$@"
    '';
    nf-lint-tf = pkgs.writeShellScriptBin "nf-lint-tf" ''
      ${getExe packages.terraform} fmt "$@" &&
      ${packages.tflint}/bin/tflint
    '';
    nf-lint-nix = pkgs.writeShellScriptBin "nf-lint-nix" ''
      ${getExe packages.nf-statix} check "$@" &&
      ${getExe packages.nf-deadnix} -f "$@"
    '';
    nf-fmt-nix = let
      inherit (fmt.nix) whitelist;
      includes = concatStringsSep " " whitelist;
    in pkgs.writeShellScriptBin "nf-fmt-nix" ''
      exec ${getExe packages.nf-alejandra} ${includes} "$@"
    '';
  };
in output
