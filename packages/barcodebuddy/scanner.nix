{
  stdenvNoCC,
  fetchpatch,
  makeWrapper,
  barcodebuddy,
  curl,
  evtest,
  screen,
  lib,
  enableCurl ? true,
  enablePhp ? false,
  php,
  ...
}: let
  inherit (lib.lists) optional optionals;
  inherit (lib.strings) makeBinPath;
in
  stdenvNoCC.mkDerivation {
    pname = "barcodebuddy-scanner";
    inherit (barcodebuddy) version src;

    patches = [
      (fetchpatch {
        name = "barcodebuddy-grab-input.patch";
        url = "https://github.com/gensokyo-zone/barcodebuddy/commit/9497d88b7971f2b47c9dcc32183721e059cd6d1d.patch";
        sha256 = "sha256-1HV5VMlXR4VoMo01KhlZ3bTdVLMJ08qzFqhqK4hBHdg=";
      })
    ];

    skipConfigure = true;
    skipBuild = true;

    nativeBuildInputs = [
      makeWrapper
    ];

    scannerSource = "example/grabInput.sh";
    scannerPath = makeBinPath (
      [evtest]
      ++ optional enableCurl curl
      ++ optionals enablePhp [screen php]
    );

    installPhase = ''
      runHook preInstall

      install -Dm 0755 $scannerSource $out/bin/barcodebuddy-grab-input

      runHook postInstall
    '';

    postInstall = ''
      wrapProgram $out/bin/barcodebuddy-grab-input \
        --set-default SCRIPT_LOCATION "''${barcodebuddyScript-/var/www/html/barcodebuddy/index.php}" \
        --prefix PATH : "$scannerPath"
    '';

    meta =
      barcodebuddy.meta
      // {
        mainProgram = "barcodebuddy-grab-input";
      };
  }
