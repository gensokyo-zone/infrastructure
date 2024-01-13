{ inputs, system }:
let
  meta = import ./meta.nix { inherit inputs system; };
  inherit (meta) pkgs;
  nf-actions = pkgs.writeShellScriptBin "nf-actions" ''
    NF_CONFIG_FILES=($NF_CONFIG_ROOT/ci/{nodes,flake-cron}.nix)
    for f in "''${NF_CONFIG_FILES[@]}"; do
      echo $f
      nix run --argstr config "$f" -f '${inputs.ci}' run.gh-actions-generate
    done
  '';
  nf-actions-test = pkgs.writeShellScriptBin "nf-actions-test" ''
    exec nix run --argstr config "$NF_CONFIG_ROOT/ci/nodes.nix" -f '${inputs.ci}' job.tewi.test
  '';
  nf-update = pkgs.writeShellScriptBin "nf-update" ''
    exec nix flake update "$@"
  '';
  nf-deploy = pkgs.writeShellScriptBin "nf-deploy" ''
    exec nix run ''${FLAKE_OPTS-} ''$NF_CONFIG_ROOT#nf-deploy -- "$@"
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

