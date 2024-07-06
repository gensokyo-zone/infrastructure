final: prev: let
  inherit (final) lib;
in {
  krb5-ldap = final.krb5.override {
    withLdap = true;
  };

  sssd = let
    inherit (prev) sssd;
    sssd'py311 = sssd.override {
      python3 = final.python311;
    };
    isBroken = !(builtins.tryEval sssd.outPath).success;
    warnFixed = lib.warnIf (lib.versionAtLeast final.python3.version "3.12") "python-ldap overlay fix no longer needed";
  in if isBroken then sssd'py311 else warnFixed sssd;

  freeipa = let
    inherit (prev) freeipa;
    freeipa'py311 = (freeipa.override {
      python3 = final.python311;
    }).overrideAttrs (old: {
      nativeBuildInputs = [
        final.python311
      ] ++ old.nativeBuildInputs;
    });
    isBroken = !(builtins.tryEval freeipa.outPath).success;
    warnFixed = lib.warnIf (lib.versionAtLeast final.python3.version "3.12") "python-ldap overlay fix no longer needed";
  in if isBroken then freeipa'py311 else warnFixed freeipa;
}
