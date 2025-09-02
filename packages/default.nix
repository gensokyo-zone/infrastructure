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
    inherit (inputs.self.lib.gensokyo-zone) systems;
    nixosSystems = set.filter (_: system: system.ci.enable) systems;
    warnSystems = set.filter (_: system: system.ci.allowFailure) nixosSystems;
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

    inherit
      (pkgs)
      freeipa-ipasam
      samba-ldap
      samba-ipa
      krb5-ldap
      nfs-utils-ldap
      barcodebuddy
      barcodebuddy-scanner
      barcodebuddy-scanner-python
      niimprint
      openwebrxplus
      systemd2mqtt
      ;

    pygrocy = pkgs.python3Packages.callPackage ./grocy/pygrocy.nix { };

    nf-setup-node = let
      defaultNodeName = "reisen";
      nodes = {
        reisen = {
          root = ../systems/reisen;
          nodeType = "proxmox";
          userReferenceSystem = "hakurei";
        };
      };
      inherit (inputs.self.lib.lib) userIs;
      INPUT_INFRABINS = string.escapeShellArg [ "putfile64" "pve" "mkpam" "ct-config" ];
      inputAuthorizedKeys = userReferenceSystem: let
        inherit (inputs.self.nixosConfigurations.${userReferenceSystem}.config) users;
        authorizedKeys = list.concatMap (user: user.openssh.authorizedKeys.keys) (
          list.filter (userIs "wheel") (set.values users.users)
        );
      in {
        base64path = pkgs.writeText "root.authorized_keys" (
          string.intercalate "\n" authorizedKeys
        );
      };
      proxmoxRoot = ../ci/proxmox;
      inputAttrs.proxmox = { root, userReferenceSystem, extraAttrs ? {}, ... }: {
        INPUT_INFRA_SETUP_NODE.base64path = root + "/setup.sh";
        inherit INPUT_INFRABINS;
        INPUT_ROOT_SSH_AUTHORIZEDKEYS = inputAuthorizedKeys userReferenceSystem;
        INPUT_TF_SSH_AUTHORIZEDKEYS.base64path = proxmoxRoot + "/tf.authorized_keys";
        INPUT_SUBUID.base64path = proxmoxRoot + "/subuid";
        INPUT_SUBGID.base64path = proxmoxRoot + "/subgid";
        INPUT_INFRA_SETUP.base64path = proxmoxRoot + "/setup.sh";
        INPUT_INFRA_PUTFILE64.base64path = proxmoxRoot + "/bin/putfile64.sh";
        INPUT_INFRA_PVE.base64path = proxmoxRoot + "/bin/pve.sh";
        INPUT_INFRA_MKPAM.base64path = proxmoxRoot + "/bin/mkpam.sh";
        INPUT_INFRA_CT_CONFIG.base64path = proxmoxRoot + "/bin/ct-config.sh";
        INPUT_AUTHRPCGSS_OVERRIDES.base64path = proxmoxRoot + "/net.auth-rpcgss-module.service.overrides";
      } // extraAttrs;
      inputVars = { nodeType, ... }@node: set.mapToValues (key: input: let
        value =
          if input ? base64path then ''"$(base64 -w0 < ${input.base64path})"''
          else string.escapeShellArg input;
      in ''${key}=${value}'') (inputAttrs.${nodeType} node);
      setInputVars = nodeName: node: ''
        NF_SETUP_NODE_NAME=''${NF_SETUP_NODE_NAME:-''${1-${defaultNodeName}}}
        NF_SETUP_INPUTS_${nodeName}=(
          ${string.intercalate "\n" (inputVars node)}
        )
      '';
    in
      pkgs.writeShellScriptBin "nf-setup-node" ''
        ${exports}
        ${string.intercalate "\n" (set.mapToValues setInputVars nodes)}
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
