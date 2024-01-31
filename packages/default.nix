{
  system,
  inputs,
  lib,
}: let
  inherit (lib.meta) getExe;
  inherit (inputs.std.lib) string list;
  packages = inputs.self.packages.${system};
  inherit (inputs.self.legacyPackages.${system}) pkgs;
  fmt = import ../ci/fmt.nix;
  output = {
    inherit (pkgs.buildPackages)
      terraform tflint
      alejandra deadnix statix
      ssh-to-age jq
    ;
    inherit (inputs.deploy-rs.packages.${system}) deploy-rs;
    nf-deploy = pkgs.writeShellScriptBin "nf-deploy" ''
      exec ${pkgs.runtimeShell} ${../ci/deploy.sh} "$@"
    '';
    nf-setup-node = let
      reisen = ../systems/reisen;
      inherit (inputs.self.nixosConfigurations.hakurei.config.users.users) arc kat;
      authorizedKeys = string.intercalate "\n" (arc.openssh.authorizedKeys.keys ++ kat.openssh.authorizedKeys.keys);
    in pkgs.writeShellScriptBin "nf-setup-node" ''
      set -eu
      SETUP_HOSTNAME=''${1-reisen}
      export INPUT_ROOT_SSH_AUTHORIZEDKEYS=${string.escapeShellArg authorizedKeys}
      exec ssh root@$SETUP_HOSTNAME env \
        INPUT_ROOT_SSH_AUTHORIZEDKEYS="$(base64 -w0 <<<"$INPUT_ROOT_SSH_AUTHORIZEDKEYS")" \
        INPUT_TF_SSH_AUTHORIZEDKEYS="$(base64 -w0 < ${reisen + "/tf.authorized_keys"})" \
        INPUT_INFRA_SETUP="$(base64 -w0 < ${reisen + "/setup.sh"})" \
        INPUT_INFRA_PUTFILE64="$(base64 -w0 < ${reisen + "/bin/putfile64.sh"})" \
        INPUT_INFRA_PVE="$(base64 -w0 < ${reisen + "/bin/pve.sh"})" \
        INPUT_INFRA_LXC_CONFIG="$(base64 -w0 < ${reisen + "/bin/lxc-config.sh"})" \
        "bash -c \"eval \\\"\\\$(base64 -d <<<\\\$INPUT_INFRA_SETUP)\\\"\""
    '';
    nf-hostname = pkgs.writeShellScriptBin "nf-hostname" ''
      set -eu
      DEPLOY_USER=
      if [[ $# -gt 1 ]]; then
        ARG_NODE=$1
        ARG_HOSTNAME=$2
        shift 2
      else
        ARG_HOSTNAME=$1
        shift
        ARG_NODE=''${ARG_HOSTNAME%%.*}
        if [[ $ARG_HOSTNAME = $ARG_NODE ]]; then
          if DEPLOY_HOSTNAME=$(nix eval --raw "''${NF_CONFIG_ROOT-${toString ../.}}"#"deploy.nodes.$ARG_HOSTNAME.hostname" 2>/dev/null); then
            DEPLOY_USER=$(nix eval --raw "''${NF_CONFIG_ROOT-${toString ../.}}"#"deploy.nodes.$ARG_HOSTNAME.sshUser" 2>/dev/null || true)
            ARG_HOSTNAME=$DEPLOY_HOSTNAME
            if ! ping -w2 -c1 "$DEPLOY_HOSTNAME" >/dev/null 2>&1; then
              ARG_HOSTNAME="$ARG_NODE.local"
            fi
          else
            ARG_HOSTNAME="$ARG_NODE.local"
          fi
        fi
      fi
      if ! ping -w2 -c1 "$ARG_HOSTNAME" >/dev/null 2>&1; then
        LOCAL_HOSTNAME=$ARG_NODE.local.gensokyo.zone
        TAIL_HOSTNAME=$ARG_NODE.tail.gensokyo.zone
        GLOBAL_HOSTNAME=$ARG_NODE.gensokyo.zone
        if ping -w2 -c1 "$LOCAL_HOSTNAME" >/dev/null 2>&1; then
          ARG_HOSTNAME=$LOCAL_HOSTNAME
        elif ping -w2 -c1 "$TAIL_HOSTNAME" >/dev/null 2>&1; then
          ARG_HOSTNAME=$TAIL_HOSTNAME
        elif ping -w2 -c1 "$GLOBAL_HOSTNAME" >/dev/null 2>&1; then
          ARG_HOSTNAME=$GLOBAL_HOSTNAME
        fi
      fi
      echo "''${DEPLOY_USER-}''${DEPLOY_USER+@}$ARG_HOSTNAME"
    '';
    nf-sshopts = pkgs.writeShellScriptBin "nf-sshopts" ''
      set -eu
      ARG_HOSTNAME=$1
      ARG_NODE=''${ARG_HOSTNAME%%.*}
      if DEPLOY_SSHOPTS=$(nix eval --json "''${NF_CONFIG_ROOT-${toString ../.}}"#"deploy.nodes.$ARG_HOSTNAME.sshOpts" 2>/dev/null); then
        SSHOPTS=($(${getExe packages.jq} -r '.[]' <<<"$DEPLOY_SSHOPTS"))
        echo "''${SSHOPTS[*]}"
      elif [[ $ARG_NODE = reisen ]]; then
        SSHOPTS=()
      else
        SSHOPTS=(''${NIX_SSHOPTS--p62954})
      fi
      if [[ $ARG_NODE = ct || $ARG_NODE = reisen-ct ]]; then
        SSHOPTS+=(-oUpdateHostKeys=no -oStrictHostKeyChecking=off)
      else
        SSHOPTS+=(-oHostKeyAlias=$ARG_NODE.gensokyo.zone)
      fi
      echo "''${SSHOPTS[*]}"
    '';
    nf-sops-keyscan = pkgs.writeShellScriptBin "nf-sops-keyscan" ''
      set -eu
      ARG_NODE=$1
      shift
      ARG_HOSTNAME=$(${getExe packages.nf-hostname} "$ARG_NODE")
      ssh-keyscan ''${NIX_SSHOPTS--p62954} "''${ARG_HOSTNAME#*@}" "$@" | ${getExe packages.ssh-to-age}
    '';
    nf-ssh = pkgs.writeShellScriptBin "nf-ssh" ''
      set -eu
      ARG_NODE=$1
      ARG_HOSTNAME=$(${getExe packages.nf-hostname} "$ARG_NODE")
      NIX_SSHOPTS=$(${getExe packages.nf-sshopts} "$ARG_NODE")
      exec ssh $NIX_SSHOPTS "$ARG_HOSTNAME"
    '';
    nf-build = pkgs.writeShellScriptBin "nf-build" ''
      set -eu
      ARG_NODE=$1
      shift
      exec nix build --no-link --print-out-paths \
        "''${NF_CONFIG_ROOT-${toString ../.}}#nixosConfigurations.$ARG_NODE.config.system.build.toplevel" \
        --show-trace "$@"
    '';
    nf-tarball = pkgs.writeShellScriptBin "nf-tarball" ''
      set -eu
      if [[ $# -gt 0 ]]; then
        ARG_NODE=$1
        shift
      else
        ARG_NODE=ct
      fi
      ARG_CONFIG_PATH=nixosConfigurations.$ARG_NODE.config
      RESULT=$(nix build --no-link --print-out-paths \
        "''${NF_CONFIG_ROOT-${toString ../.}}#$ARG_CONFIG_PATH.system.build.tarball" \
        --show-trace "$@")
      if [[ $ARG_NODE = ct ]]; then
        DATESTAMP=$(nix eval --raw "''${NF_CONFIG_ROOT-${toString ../.}}#inputs.nixpkgs.sourceInfo.lastModifiedDate")
        DATENAME=''${DATESTAMP:0:4}''${DATESTAMP:4:2}''${DATESTAMP:6:2}
        SYSARCH=$(nix eval --raw "''${NF_CONFIG_ROOT-${toString ../.}}#$ARG_CONFIG_PATH.nixpkgs.system")
        TAREXT=$(nix eval --raw "''${NF_CONFIG_ROOT-${toString ../.}}#$ARG_CONFIG_PATH.system.build.tarball.extension")
        TARNAME=nixos-system-$SYSARCH.tar$TAREXT
        OUTNAME="ct-$DATENAME-$TARNAME"
        ln -sf "$RESULT/tarball/$TARNAME" "$OUTNAME"
        echo $OUTNAME
        ls -l $OUTNAME
      fi
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
      excludes = "${getExe pkgs.buildPackages.findutils} ${string.intercalate " " blacklistDirs} -type f";
    in pkgs.writeShellScriptBin "nf-deadnix" ''
      exec ${getExe packages.deadnix} "$@" \
        --no-lambda-arg \
        --exclude $(${excludes})
    '';
    nf-alejandra = let
      inherit (fmt.nix) blacklistDirs;
      excludes = string.intercalate " " (list.map (dir: "--exclude ${dir}") blacklistDirs);
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
      includes = string.intercalate " " whitelist;
    in pkgs.writeShellScriptBin "nf-fmt-nix" ''
      exec ${getExe packages.nf-alejandra} ${includes} "$@"
    '';
  };
in output
