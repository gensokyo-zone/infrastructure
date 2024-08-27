{
  stdenvNoCC,
  fetchFromGitHub,
  fetchpatch,
  lib,
  ...
}: let
  inherit (lib.strings) removePrefix;
  inherit (lib.trivial) importJSON;
  lock = importJSON ../../flake.lock;
  inherit (lock.nodes) barcodebuddy;
in
  stdenvNoCC.mkDerivation {
    pname = "barcodebuddy";
    version = removePrefix "v" barcodebuddy.original.ref;

    src = fetchFromGitHub {
      inherit (barcodebuddy.locked) repo owner rev;
      sha256 = barcodebuddy.locked.narHash;
    };
    patches = [
      (fetchpatch {
        name = "barcodebuddy-quantity.patch";
        url = "https://github.com/gensokyo-zone/barcodebuddy/commit/c46416b40540da0bef4841c2ddf884fa7dd152fe.diff";
        sha256 = "sha256-PPVZ996Tm+/YkzECFsy1PJQMCjk3+i9jQuOawYzXRgU=";
      })
    ];

    skipConfigure = true;
    skipBuild = true;

    installPhase = ''
      runHook preInstall

      install -d $out
      cp -ar api/ incl/ locales/ menu/ plugins/ *.php $out/

      runHook postInstall
    '';

    meta = {
      homepage = "https://github.com/Forceu/barcodebuddy";
      license = lib.licenses.agpl3Plus;
    };
  }
