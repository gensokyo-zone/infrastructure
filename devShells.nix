{
  inputs,
  system,
}: let
  inherit (inputs.self.legacyPackages.${system}) pkgs;
  inherit (inputs.self.lib.lib) mkBaseDn;
  inherit (inputs.self.lib.nixlib) optionalString concatStringsSep;
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
      ${optionalString (subdir != null) ''cd "''${NF_CONFIG_ROOT-${toString ./.}}${subdir}"''}
      exec nix ${subcommand} ''${FLAKE_OPTS-} "''${NF_CONFIG_ROOT-${toString ./.}}#${attr}" ${exeArg} "$@"
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
      nf-tf
      (mkWrapper {name = "nf-update";})
      (mkWrapper {name = "nf-actions-test";})
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
      (mkWrapper rec {
        name = "smbclient";
        attr = "pkgs.samba";
        exe = name;
      })
      (mkWrapper rec {
        name = "smbpasswd";
        attr = "pkgs.samba";
        exe = name;
      })
      (mkWrapper rec {
        name = "net";
        attr = "pkgs.samba";
        exe = name;
      })
      (mkWrapper rec {
        name = "ldapwhoami";
        attr = "pkgs.openldap";
        exe = name;
      })
      (mkWrapper rec {
        name = "ldappasswd";
        attr = "pkgs.openldap";
        exe = name;
      })
      (mkWrapper rec {
        name = "ldapsearch";
        attr = "pkgs.openldap";
        exe = ''${name} -o ldif_wrap=no'';
      })
      (mkWrapper rec {
        name = "ldapadd";
        attr = "pkgs.openldap";
        exe = name;
      })
      (mkWrapper rec {
        name = "ldapmodify";
        attr = "pkgs.openldap";
        exe = name;
      })
      (mkWrapper rec {
        name = "ldapdelete";
        attr = "pkgs.openldap";
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
    LDAPURI = concatStringsSep "," [
      "ldaps://ldap.local.${inputs.self.lib.lib.domain}"
      "ldaps://idp.${inputs.self.lib.lib.domain}"
    ];
    LDAPBASE = mkBaseDn inputs.self.lib.lib.domain;
  };
  arc = let
    ldapdm = cmd: pkgs.writeShellScriptBin "dm-${cmd}" ''
      ${cmd} -D 'cn=Directory Manager' -y <(bitw get -f password ldap-directory-manager) "$@"
    '';
  in default.overrideAttrs (default: {
    nativeBuildInputs = default.nativeBuildInputs ++ [
      (ldapdm "ldapwhoami")
      (ldapdm "ldappasswd")
      (ldapdm "ldapsearch")
      (ldapdm "ldapadd")
      (ldapdm "ldapmodify")
      (ldapdm "ldapdelete")
    ];
  });
in {
  inherit default arc;
}
