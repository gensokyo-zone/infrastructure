{
  inputs,
  system,
}: let
  inherit (inputs.self.legacyPackages.${system}) pkgs;
  inherit (inputs.self.lib.nixlib) optionalString;
  mkWrapper = {
    name,
    attr ? name,
    subdir ? null,
    exe ? null,
  }: let
    subcommand =
      if exe == null
      then "run"
      else "shell";
    exeArg =
      if exe == null
      then "--"
      else "-c ${exe}";
  in
    pkgs.writeShellScriptBin name ''
      ${optionalString (subdir != null) ''cd "$NF_CONFIG_ROOT${subdir}"''}
      exec nix ${subcommand} ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#${attr}" ${exeArg} "$@"
    '';
  nf-actions = pkgs.writeShellScriptBin "nf-actions" ''
    NF_CONFIG_FILES=($NF_CONFIG_ROOT/ci/{nodes,flake-cron}.nix)
    for f in "''${NF_CONFIG_FILES[@]}"; do
      echo $f
      nix run --argstr config "$f" -f '${inputs.ci}' run.gh-actions-generate
    done
  '';
  nf-actions-test = pkgs.writeShellScriptBin "nf-actions-test" ''
    set -eu
    for host in hakurei reimu aya tei mediabox ct; do
      nix run --argstr config "$NF_CONFIG_ROOT/ci/nodes.nix" -f '${inputs.ci}' job.$host.test
    done
  '';
  nf-update = pkgs.writeShellScriptBin "nf-update" ''
    exec nix flake update "$@"
  '';
  nf-tf = pkgs.writeShellScriptBin "nf-tf" ''
    cd "$NF_CONFIG_ROOT/tf"
    if [[ $# -eq 0 ]]; then
      exec nix shell ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#terraform" -c bash -c "terraform init && terraform plan"
    else
      exec nix run ''${FLAKE_OPTS-} "$NF_CONFIG_ROOT#terraform" -- "$@"
    fi
  '';
  default = pkgs.mkShell {
    nativeBuildInputs = with pkgs; [
      inetutils
      sops
      nf-actions
      nf-actions-test
      nf-update
      nf-tf
      (mkWrapper {name = "nf-docs";})
      (mkWrapper {name = "nf-generate";})
      (mkWrapper {name = "nf-setup-node";})
      (mkWrapper {name = "nf-sops-keyscan";})
      (mkWrapper {name = "nf-ssh";})
      (mkWrapper {name = "nf-build";})
      (mkWrapper {name = "nf-tarball";})
      (mkWrapper {name = "nf-switch";})
      (mkWrapper {
        name = "nf-lint-tf";
        subdir = "/tf";
      })
      (mkWrapper {
        name = "nf-fmt-tf";
        subdir = "/tf";
      })
      (mkWrapper {
        name = "nf-lint-nix";
        subdir = "";
      })
      (mkWrapper {
        name = "nf-fmt-nix";
        subdir = "";
      })
      (mkWrapper {name = "nf-alejandra";})
      (mkWrapper {
        name = "statix";
        attr = "nf-statix";
      })
      (mkWrapper {
        name = "deadnix";
        attr = "nf-deadnix";
      })
      (mkWrapper {
        name = "kustomize";
        attr = "pkgs.kustomize";
      })
      (mkWrapper {
        name = "argocd";
        attr = "pkgs.argocd";
      })
      (mkWrapper rec {
        name = "deploy";
        attr = "deploy-rs";
        exe = name;
      })
      (mkWrapper rec {
        name = "smbencrypt";
        attr = "pkgs.freeradius";
        exe = name;
      })
    ];
    shellHook = ''
      export NIX_BIN_DIR=$(dirname $(readlink -f $(type -P nix)))
      export HOME_UID=$(id -u)
      export HOME_USER=$(id -un)
      export CI_PLATFORM="impure"
      export NF_CONFIG_ROOT=''${NF_CONFIG_ROOT-${toString ./.}}
    '';
  };
in {
  inherit default;
}
