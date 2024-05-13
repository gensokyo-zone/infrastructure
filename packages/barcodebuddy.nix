{
  stdenvNoCC,
  fetchFromGitHub,
  lib,
  ...
}: let
  inherit (lib.strings) removePrefix;
  inherit (lib.trivial) importJSON;
  lock = importJSON ../flake.lock;
  inherit (lock.nodes) barcodebuddy;
in
  stdenvNoCC.mkDerivation {
    pname = "barcodebuddy";
    version = removePrefix "v" barcodebuddy.original.ref;
    src = fetchFromGitHub {
      inherit (barcodebuddy.locked) repo owner rev;
      sha256 = barcodebuddy.locked.narHash;
    };
    skipConfigure = true;
    skipBuild = true;

    installPhase = ''
      runHook preInstall

      install -d $out
      cp -ar api/ incl/ locales/ menu/ plugins/ *.php $out/

      runHook postInstall
    '';
  }
