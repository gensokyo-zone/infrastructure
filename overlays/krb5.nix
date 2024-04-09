final: prev: let
  inherit (final) lib;
in {
  krb5-ldap = final.krb5.override {
    withLdap = true;
  };
  _389-ds-base = let
    inherit (prev) _389-ds-base;
    drv = _389-ds-base.overrideAttrs (old: {
      patches = old.patches or [ ] ++ [
        ../packages/389-ds-base-fix.patch
        (final.fetchpatch {
          name = "389-ds-base-5973-f_un.patch";
          url = "https://github.com/389ds/389-ds-base/pull/5974.patch";
          sha256 = "sha256-WtctQPZVZSAbPg2tjY7wD8ysI4SKkfyS5tQx0NPhSmY=";
        })
        (final.fetchpatch {
          name = "389-ds-base-5962-f_un.patch";
          url = "https://github.com/389ds/389-ds-base/pull/6089.patch";
          sha256 = "sha256-b0HSaDjuEUKERIXKg8np+lZDdZNmrCTAXybJzF+0hq0=";
        })
      ];
      meta = old.meta // {
        broken = false;
      };
    });
  in if _389-ds-base.meta.broken or false && _389-ds-base.version == "2.4.3" then drv else lib.warn "389-ds patch/overlay no longer needed" _389-ds-base;
}
