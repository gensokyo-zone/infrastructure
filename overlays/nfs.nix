final: prev: {
  # https://github.com/NixOS/nixpkgs/pull/342130
  nfs-utils-ldap = prev.nfs-utils.overrideAttrs (old: {
    buildInputs =
      old.buildInputs
      ++ [
        final.cyrus_sasl
      ];
    configureFlags =
      old.configureFlags
      ++ [
        "--enable-ldap"
      ];
  });
}
