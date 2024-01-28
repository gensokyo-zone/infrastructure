{
  inputs,
  system,
}: let
  inherit (inputs.self.legacyPackages.${system}) pkgs;
  nf-actions = pkgs.writeShellScriptBin "nf-actions" ''
    NF_CONFIG_FILES=($NF_CONFIG_ROOT/ci/{nodes,flake-cron}.nix)
    for f in "''${NF_CONFIG_FILES[@]}"; do
      echo $f
      nix run --argstr config "$f" -f '${inputs.ci}' run.gh-actions-generate
    done
  '';
  nf-actions-test = pkgs.writeShellScriptBin "nf-actions-test" ''
    set -eu
    for host in hakurei tei mediabox ct; do
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
    if [[ $# -eq 0 ]]; then
      exec nix shell ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#terraform" -c bash -c "terraform init && terraform plan"
    else
      exec nix run ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#terraform" -- "$@"
    fi
  '';
  nf-lint-tf = pkgs.writeShellScriptBin "nf-lint-tf" ''
    cd "$NF_CONFIG_ROOT/tf"
    exec nix run ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#nf-lint-tf" -- "$@"
  '';
  nf-lint-nix = pkgs.writeShellScriptBin "nf-lint-nix" ''
    cd "$NF_CONFIG_ROOT"
    exec nix run ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#nf-lint-nix" -- "$@"
  '';
  nf-fmt-nix = pkgs.writeShellScriptBin "nf-fmt-nix" ''
    cd "$NF_CONFIG_ROOT"
    exec nix run ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#nf-fmt-nix" -- "$@"
  '';
  nf-alejandra = pkgs.writeShellScriptBin "alejandra" ''
    cd "$NF_CONFIG_ROOT"
    exec nix run ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#nf-alejandra" -- "$@"
  '';
  nf-statix = pkgs.writeShellScriptBin "statix" ''
    cd "$NF_CONFIG_ROOT"
    exec nix run ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#nf-statix" -- "$@"
  '';
  nf-deadnix = pkgs.writeShellScriptBin "deadnix" ''
    cd "$NF_CONFIG_ROOT"
    exec nix run ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#nf-deadnix" -- "$@"
  '';
  nf-kustomize = pkgs.writeShellScriptBin "kustomize" ''
    exec nix run ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#pkgs.kustomize" -- "$@"
  '';
  nf-argocd = pkgs.writeShellScriptBin "argocd" ''
    exec nix run ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#pkgs.argocd" -- "$@"
  '';
  nf-deploy-rs = pkgs.writeShellScriptBin "deploy" ''
    cd "$NF_CONFIG_ROOT"
    exec nix shell ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#deploy-rs" -c deploy "$@"
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
      nf-lint-nix
      nf-fmt-nix
      nf-alejandra
      nf-statix
      nf-deadnix
      nf-kustomize
      nf-argocd
      nf-deploy-rs
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
