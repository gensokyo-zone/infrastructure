final: prev: let
  inherit (final) lib;
in {
  krb5-ldap = final.krb5.override {
    withLdap = true;
  };

  _389-ds-base = let
    inherit (final) fetchpatch;
    inherit (prev) _389-ds-base;
    revertdyncert = fetchpatch {
      # requires nss/pk11wrap...
      name = "389-ds-base-revert-dyncert.patch";
      url = "https://github.com/389ds/389-ds-base/pull/7117.diff";
      hash = "sha256-CpJbw4fzQpHbed/znsYrBEF3mhdFixohOJJArSoGLFU=";
      revert = true;
      includes = [
        "ldap/servers/slapd/ssl.c"
        "Makefile.am"
        "ldap/servers/slapd/mapping_tree.c"
      ];
    };
    patchCount = lib.length _389-ds-base.patches or [];
    addDyncert = true;
    drv' = if addDyncert then _389-ds-base.override { nss = final.nss_latest; } else _389-ds-base;
    drv = drv'.overrideAttrs (old: rec {
      version = "3.1-20260330";
      src = final.fetchFromGitHub {
        owner = "389ds";
        repo = "389-ds-base";
        rev = "1e547c42a045b14b664e8f2d2f333cbd4768cf3f";
        hash = "sha256-vw+07uui7IscDjUSzdh6e+WEq3/4s1E6JA6qMl6uVXo=";
      };
      patches = if addDyncert then [] else [revertdyncert];
      cargoDeps = final.rustPlatform.fetchCargoVendor {
        inherit src;
        sourceRoot = "${src.name}/src";
        name = "389-ds-base-${version}";
        hash = "sha256-ZVabQ/SAnhg9uwmLAkwqBU2tHhUQ6jOKLEvOekNkKPU=";
      };
      preConfigure = lib.optionalString addDyncert ''
        #sed -e '/dyncerts\.c/d' -i Makefile.am
        #sed -e '/dyncerts_register_socket/d' -i ldap/servers/slapd/ssl.c
        sed -e 's|include <nss3/|include <nss/|' -i ldap/servers/slapd/dyncerts.c
      '' + old.preConfigure or "";
      preBuild = ''
        ln -s ${cargoDeps}/source-registry-0 ./vendor
        ls -l vendor/
      '';
    });
  in if _389-ds-base.version == "3.1.3" && patchCount <= 1
    then drv
    else lib.warn "389-ds-base patch probably no longer needed" _389-ds-base;
}
