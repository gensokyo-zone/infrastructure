final: prev: {
  # https://github.com/NixOS/nixpkgs/pull/286793
  nfs-utils-ldap = prev.nfs-utils.overrideAttrs (old: {
    buildInputs =
      old.buildInputs
      ++ [
        final.openldap
        (final.cyrus_sasl.override {
          openssl = final.openssl_legacy;
        })
      ];
    configureFlags =
      old.configureFlags
      ++ [
        "--enable-ldap"
      ];
  });
}
