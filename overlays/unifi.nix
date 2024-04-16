final: prev: let
  inherit (final) lib;
in {
  mongodb-5_0 = let
    mongodb-5_0_26 = prev.mongodb-5_0.overrideAttrs (old: rec {
      version = "5.0.26";
      name = "${old.pname}-${version}";
      src = final.fetchurl {
        url = "https://fastdl.mongodb.org/src/mongodb-src-r${version}.tar.gz";
        sha256 = "sha256-GGvE52zCu2tg4p35XJ5I78nBxRUp4KwBqlmtiv50N7w=";
      };
    });
  in lib.warnIf (lib.versionAtLeast prev.mongodb-5_0.version "5.0.26") "mongodb 5.0 updated in upstream nixpkgs, overlay no longer needed" mongodb-5_0_26;
}
