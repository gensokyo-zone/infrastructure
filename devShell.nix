{
  inputs,
  system,
}: let
  meta = import ./meta.nix {inherit inputs system;};
  inherit (meta) pkgs;
  nf-actions = pkgs.writeShellScriptBin "nf-actions" ''
    NF_CONFIG_FILES=($NF_CONFIG_ROOT/ci/{nodes,flake-cron}.nix)
    for f in "''${NF_CONFIG_FILES[@]}"; do
      echo $f
      nix run --argstr config "$f" -f '${inputs.ci}' run.gh-actions-generate
    done
  '';
  nf-actions-test = pkgs.writeShellScriptBin "nf-actions-test" ''
    set -eu
    for host in hakurei tei mediabox reisen-ct; do
      nix run --argstr config "$NF_CONFIG_ROOT/ci/nodes.nix" -f '${inputs.ci}' job.$host.test
    done
  '';
  nf-update = pkgs.writeShellScriptBin "nf-update" ''
    exec nix flake update "$@"
  '';
  nf-deploy = pkgs.writeShellScriptBin "nf-deploy" ''
    exec nix run ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#nf-deploy" -- "$@"
  '';
  nf-tf = pkgs.writeShellScriptBin "nf-tf" ''
    cd "$NF_CONFIG_ROOT/tf"
    exec nix run ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#terraform" -- "$@"
  '';
  nf-lint-tf = pkgs.writeShellScriptBin "nf-lint-tf" ''
    cd "$NF_CONFIG_ROOT/tf"
    exec nix run ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#nf-lint-tf" -- "$@"
  '';
  nf-kustomize = pkgs.writeShellScriptBin "kustomize" ''
    exec nix run ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#pkgs.kustomize" -- "$@"
  '';
  nf-argocd = pkgs.writeShellScriptBin "argocd" ''
    exec nix run ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#pkgs.argocd" -- "$@"
  '';
in
  pkgs.mkShell {
    nativeBuildInputs = with pkgs; [
      inetutils
      sops
      nf-actions
      nf-actions-test
      nf-update
      nf-deploy
      nf-tf
      nf-lint-tf
      nf-kustomize
      nf-argocd
    ];
    shellHook = ''
      export NIX_BIN_DIR=$(dirname $(readlink -f $(type -P nix)))
      export HOME_UID=$(id -u)
      export HOME_USER=$(id -un)
      export CI_PLATFORM="impure"
      export NF_CONFIG_ROOT=''${NF_CONFIG_ROOT-${toString ./.}}
      export NIX_PATH="$NIX_PATH:home=$NF_CONFIG_ROOT"
      export NIX_SSHOPTS="''${NIX_SSHOPTS--p62954}"
    '';
  }
