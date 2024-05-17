{
  stdenvNoCC,
  makeWrapper,
  barcodebuddy,
  barcodebuddy-scanner,
  screen,
  lib,
  enableRequests ? true,
  enablePhp ? false,
  php,
  python3,
  ...
}: let
  inherit (lib.lists) optional optionals;
  inherit (lib.strings) makeBinPath;
  python = python3.withPackages (
    p:
      [p.evdev]
      ++ optional enableRequests p.requests
  );
in
  stdenvNoCC.mkDerivation {
    pname = "barcodebuddy-scanner.py";
    inherit (barcodebuddy) version src;
    inherit (barcodebuddy-scanner) patches meta;

    skipConfigure = true;
    skipBuild = true;

    nativeBuildInputs = [
      makeWrapper
    ];

    buildInputs = [python];

    scannerPath = makeBinPath (
      optionals enablePhp [screen php]
    );
    ${
      if enablePhp
      then "barcodebuddyScript"
      else null
    } = "${barcodebuddy}/index.php";

    scannerSource = "example/grabInput.py";
    inherit (barcodebuddy-scanner) installPhase postInstall;
  }
