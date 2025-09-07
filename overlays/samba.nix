final: prev: let
  inherit (final) lib;
in {
  freeipa-ipasam = let
    attrs = old: {
      pname = "freeipa-ipasam";
      patches =
        old.patches
        or []
        ++ [
          ../packages/freeipa-ipasam.patch
        ];
      configureFlags = lib.filter (f: f != "--disable-server") old.configureFlags;
      nativeBuildInputs = old.nativeBuildInputs or []
        # wants 1.17 normally
        ++ lib.optional (lib.versionAtLeast final.automake.version "1.18") final.autoreconfHook
      ;
    };
    overrides = {
      samba = final.samba-ldap;
    };
  in
    (final.freeipa.override overrides).overrideAttrs attrs;

  samba-ldap = final.samba.override {
    enableLDAP = true;
  };

  samba-ipa = final.samba-ldap.overrideAttrs (old: {
    buildInputs =
      old.buildInputs
      ++ [
        final.freeipa-ipasam
      ];
    postInstall = ''
      ${old.postInstall or ""}
      cp -a ${final.freeipa-ipasam}/lib/samba/pdb/ipasam.so $out/lib/samba/pdb/
    '';
  });
}
