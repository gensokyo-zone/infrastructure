{
  buildPythonApplication,
  fetchFromGitHub,
  poetry-core,
  pyserial,
  pillow,
  click,
}: let
  mainProgram = "niimprint";
in
  buildPythonApplication {
    pname = "niimprint";
    version = "2024_04_05";

    src = fetchFromGitHub {
      owner = "AndBondStyle";
      repo = "niimprint";
      rev = "be39f68c16a5a7dc1b09bb173700d0ee1ec9cb66";
      sha256 = "sha256-+YISYchdqeVKrQ0h2cj5Jy2ezMjnQcWCCYm5f95H9dI=";
    };

    pyproject = true;

    nativeBuildInputs = [
      poetry-core
    ];

    propagatedBuildInputs = [
      pyserial
      pillow
      click
    ];

    postInstall = ''
      install -d $out/bin
      echo '#!/usr/bin/env python' > $out/bin/${mainProgram}
      cat niimprint/__main__.py >> $out/bin/${mainProgram}
      chmod +x $out/bin/${mainProgram}
    '';

    meta = {
      inherit mainProgram;
    };
  }
