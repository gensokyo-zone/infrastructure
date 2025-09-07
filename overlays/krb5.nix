final: prev: let
  inherit (final) lib;
in {
  krb5-ldap = final.krb5.override {
    withLdap = true;
  };

  _389-ds-base = let
    inherit (final) fetchpatch;
    inherit (prev) _389-ds-base;
    rust189warning = fetchpatch {
      name = "389-ds-base-rust189.patch";
      url = "https://github.com/389ds/389-ds-base/commit/1701419551c246e9dc21778b118220eeb2258125.patch";
      hash = "sha256-trzY/fDH3rs66DWbWI+PY46tIC9ShuVqspMHqEEKZYA=";
    };
    drv = _389-ds-base.overrideAttrs (old: {
      patches = old.patches or [] ++ [
        rust189warning
      ];
    });
  in if _389-ds-base.version == "3.1.3" && _389-ds-base.patches or [] == []
    then drv
    else lib.warn "389-ds-base patch probably no longer needed" _389-ds-base;
}
