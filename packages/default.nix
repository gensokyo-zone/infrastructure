{
  system,
  inputs,
}: let
  lib = inputs.self.lib.nixlib;
  inherit (lib.strings) makeBinPath;
  inherit (inputs.self.lib.std) string list set;
  packages = inputs.self.packages.${system};
  inherit (inputs.self.legacyPackages.${system}) pkgs;
  fmt = import ../ci/fmt.nix;
  inherit (import ../ci/nix.nix) ci;
  exports = ''
    export NF_CONFIG_ROOT=''${NF_CONFIG_ROOT-${toString ../.}}
  '';
  exportsSsh = ''
    export PATH="${makeBinPath [packages.nf-hostname packages.nf-sshopts]}:$PATH"
  '';
  exportsFmtNix = ''
    NF_NIX_BLACKLIST_DIRS=(${string.concatMapSep " " string.escapeShellArg fmt.nix.blacklistDirs})
    NF_NIX_WHITELIST_DIRS=(${string.concatMapSep " " string.escapeShellArg fmt.nix.whitelistDirs})
    NF_NIX_WHITELIST_FILES=(${string.concatMapSep " " string.escapeShellArg fmt.nix.whitelist})
  '';
  exportsSystems = let
    inherit (inputs.self.lib) systems;
    nixosSystems = set.filter (_: system: system.config.ci.enable) systems;
    warnSystems = set.filter (_: system: system.config.ci.allowFailure) nixosSystems;
    toSystems = systems: string.concatMapSep " " string.escapeShellArg (set.keys systems);
  in ''
    NF_NIX_SYSTEMS=(${toSystems nixosSystems})
    NF_NIX_SYSTEMS_WARN=(${toSystems warnSystems})
  '';
  output = {
    inherit
      (pkgs.buildPackages)
      terraform
      tflint
      alejandra
      deadnix
      statix
      ssh-to-age
      jq
      ;
    inherit (inputs.deploy-rs.packages.${system}) deploy-rs;

    inherit (pkgs) freeipa-ipasam samba-ldap samba-ipa;

    nf-setup-node = let
      reisen = ../systems/reisen;
      inherit (inputs.self.lib.lib) userIs;
      inherit (inputs.self.nixosConfigurations.hakurei.config) users;
      authorizedKeys = list.concatMap (user: user.openssh.authorizedKeys.keys) (
        list.filter (userIs "wheel") (set.values users.users)
      );
      inputAttrs = {
        INPUT_ROOT_SSH_AUTHORIZEDKEYS = pkgs.writeText "root.authorized_keys" (
          string.intercalate "\n" authorizedKeys
        );
        INPUT_TF_SSH_AUTHORIZEDKEYS = reisen + "/tf.authorized_keys";
        INPUT_SUBUID = reisen + "/subuid";
        INPUT_SUBGID = reisen + "/subgid";
        INPUT_INFRA_SETUP = reisen + "/setup.sh";
        INPUT_INFRA_PUTFILE64 = reisen + "/bin/putfile64.sh";
        INPUT_INFRA_PVE = reisen + "/bin/pve.sh";
        INPUT_INFRA_MKPAM = reisen + "/bin/mkpam.sh";
        INPUT_INFRA_CT_CONFIG = reisen + "/bin/ct-config.sh";
        INPUT_AUTHRPCGSS_OVERRIDES = reisen + "/net.auth-rpcgss-module.service.overrides";
      };
      inputVars = set.mapToValues (key: path: ''${key}="$(base64 -w0 < ${path})"'') inputAttrs;
    in
      pkgs.writeShellScriptBin "nf-setup-node" ''
        ${exports}
        NF_SETUP_INPUTS=(
          ${string.intercalate "\n" inputVars}
        )
        source ${../ci/setup.sh}
      '';
    nf-actions-test = pkgs.writeShellScriptBin "nf-actions-test" ''
      ${exports}
      ${exportsSystems}
      source ${../ci/actions-test.sh}
    '';
    nf-update = pkgs.writeShellScriptBin "nf-update" ''
      ${exports}
      export PATH="${makeBinPath [packages.nf-actions-test pkgs.cachix]}:$PATH"
      source ${../ci/update.sh}
    '';
    nf-hostname = pkgs.writeShellScriptBin "nf-hostname" ''
      ${exports}
      source ${../ci/hostname.sh}
    '';
    nf-sshopts = pkgs.writeShellScriptBin "nf-sshopts" ''
      ${exports}
      export PATH="$PATH:${makeBinPath [pkgs.jq]}"
      source ${../ci/sshopts.sh}
    '';
    nf-sops-keyscan = pkgs.writeShellScriptBin "nf-sops-keyscan" ''
      ${exports}
      ${exportsSsh}
      export PATH="$PATH:${makeBinPath [pkgs.ssh-to-age]}"
      source ${../ci/sops-keyscan.sh}
    '';
    nf-ssh = pkgs.writeShellScriptBin "nf-ssh" ''
      ${exports}
      ${exportsSsh}
      source ${../ci/ssh.sh}
    '';
    nf-build = pkgs.writeShellScriptBin "nf-build" ''
      ${exports}
      source ${../ci/build.sh}
    '';
    nf-tarball = pkgs.writeShellScriptBin "nf-tarball" ''
      ${exports}
      source ${../ci/tarball.sh}
    '';
    nf-switch = pkgs.writeShellScriptBin "nf-switch" ''
      ${exports}
      ${exportsSsh}
      source ${../ci/switch.sh}
    '';
    nf-generate = pkgs.writeShellScriptBin "nf-generate" ''
      ${exports}
      export PATH="$PATH:${makeBinPath [pkgs.jq]}"
      NF_INPUT_CI=${string.escapeShellArg inputs.ci}
      NF_CONFIG_FILES=(${string.concatMapSep " " string.escapeShellArg ci.workflowConfigs})
      source ${../ci/generate.sh}
    '';
    nf-statix = pkgs.writeShellScriptBin "nf-statix" ''
      ${exports}
      export PATH="${makeBinPath [packages.statix]}:$PATH"
      source ${../ci/statix.sh}
    '';
    nf-deadnix = pkgs.writeShellScriptBin "nf-deadnix" ''
      ${exports}
      ${exportsFmtNix}
      export PATH="${makeBinPath [packages.deadnix pkgs.findutils]}:$PATH"
      source ${../ci/deadnix.sh}
    '';
    nf-alejandra = pkgs.writeShellScriptBin "nf-alejandra" ''
      ${exports}
      ${exportsFmtNix}
      export PATH="${makeBinPath [packages.alejandra]}:$PATH"
      source ${../ci/alejandra.sh}
    '';
    nf-lint-tf = pkgs.writeShellScriptBin "nf-lint-tf" ''
      ${exports}
      export PATH="$PATH:${makeBinPath [packages.tflint]}"
      source ${../ci/lint-tf.sh}
    '';
    nf-lint-nix = pkgs.writeShellScriptBin "nf-lint-nix" ''
      ${exports}
      export PATH="${makeBinPath [packages.nf-statix packages.nf-deadnix]}:$PATH"
      source ${../ci/lint-nix.sh}
    '';
    nf-fmt-tf = pkgs.writeShellScriptBin "nf-fmt-tf" ''
      ${exports}
      export PATH="${makeBinPath [packages.terraform]}:$PATH"
      source ${../ci/fmt-tf.sh}
    '';
    nf-fmt-nix = pkgs.writeShellScriptBin "nf-fmt-nix" ''
      ${exports}
      ${exportsFmtNix}
      export PATH=":{makeBinPath [ packages.nf-alejandra ]}:$PATH"
      source ${../ci/fmt-nix.sh}
    '';
    nf-docs = pkgs.writeShellScriptBin "nf-docs" ''
      ${exports}
      export NF_DOCS_PATH=${packages.docs}
      source ${../ci/docs.sh}
    '';
    docs = pkgs.callPackage ../docs/derivation.nix {
      inherit (inputs) self;
    };
  };
in
  output
