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
    isUpdated = lib.versionAtLeast freeipa.version "4.12.2";
    isPythonUpdated = lib.versionAtLeast final.python3.version "3.12";
    warnFixed = lib.warnIf isUpdated "freeipa python overlay fix probably no longer needed";
  in if isPythonUpdated && (isBroken || !isUpdated) then freeipa'py311 else warnFixed freeipa;
}
