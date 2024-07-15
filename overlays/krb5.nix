final: prev: let
  inherit (final) lib;
in {
  krb5-ldap = final.krb5.override {
    withLdap = true;
  };

  freeipa = let
    inherit (prev) freeipa;
    python3 = final.python311;
    freeipa'py311 = (freeipa.override {
      inherit python3;
    }).overrideAttrs (old: {
      nativeBuildInputs = [
        python3
      ] ++ old.nativeBuildInputs;
    });
    isBroken = !(builtins.tryEval freeipa.outPath).success;
    warnFixed = lib.warnIf (lib.versionAtLeast final.python3.version "3.12") "freeipa python overlay fix no longer needed";
  in if isBroken then freeipa'py311 else warnFixed freeipa;
}
