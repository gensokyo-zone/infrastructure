final: prev: let
  inherit (final) lib;
in {
  gerbera = prev.gerbera.overrideAttrs (old: {
    patches = old.patches or [] ++ [
      (final.fetchpatch {
        url = "https://github.com/gerbera/gerbera/pull/3721.patch";
        sha256 = "sha256-3VCfgLZJjevMvs5ifSelcRJkA2F1++YW9U+hZ9JdQIU=";
        excludes = [ "ChangeLog.md" ];
      })
    ];
  });
}
