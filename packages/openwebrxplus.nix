{
  stdenv,
  lib,
  buildPythonPackage,
  buildPythonApplication,
  fetchFromGitHub,
  pkg-config,
  cmake,
  ninja,
  setuptools,
  python,
  libsamplerate,
  fftwFloat,
  rtl-sdr,
  soapysdr-with-plugins,
  pydigiham,
  direwolf,
  sox,
  wsjtx,
  codecserver,
}: let
  js8py = buildPythonPackage rec {
    pname = "js8py";
    version = "0.1.1";

    src = fetchFromGitHub {
      owner = "jketterl";
      repo = pname;
      rev = version;
      sha256 = "1j80zclg1cl5clqd00qqa16prz7cyc32bvxqz2mh540cirygq24w";
    };
    format = "setuptools";

    pythonImportsCheck = ["js8py" "test"];

    meta = with lib; {
      homepage = "https://github.com/jketterl/js8py";
      description = "A library to decode the output of the js8 binary of JS8Call";
      license = licenses.gpl3Only;
      maintainers = teams.c3d2.members;
    };
  };

  csdr-eti = stdenv.mkDerivation rec {
    pname = "csdr-eti";
    version = "0.0.11";

    src = fetchFromGitHub {
      owner = "luarvique";
      repo = pname;
      rev = version;
      hash = "sha256-jft4zi1mLU6zZ+2gsym/3Xu8zkKL0MeoztcyMPM0RYI=";
    };

    nativeBuildInputs = [
      cmake
      ninja
      pkg-config
    ];

    propagatedBuildInputs = [
      fftwFloat
      libsamplerate
    ];
    buildInputs = [
      csdr
    ];

    hardeningDisable = lib.optional stdenv.isAarch64 "format";

    meta = with lib; {
      homepage = "https://github.com/jketterl/csdr";
      description = "A simple DSP library and command-line tool for Software Defined Radio";
      license = licenses.gpl3Only;
      platforms = platforms.unix;
      broken = stdenv.isDarwin;
      maintainers = teams.c3d2.members;
    };
  };

  csdr = stdenv.mkDerivation rec {
    pname = "csdr";
    version = "0.18.23";

    src = fetchFromGitHub {
      owner = "luarvique";
      repo = pname;
      rev = version;
      hash = "sha256-Q7g1OqfpAP6u78zyHjLP2ASGYKNKCAVv8cgGwytZ+cE=";
    };

    nativeBuildInputs = [
      cmake
      ninja
      pkg-config
    ];

    propagatedBuildInputs = [
      fftwFloat
      libsamplerate
    ];

    hardeningDisable = lib.optional stdenv.isAarch64 "format";

    postFixup = ''
      substituteInPlace "$out"/lib/pkgconfig/csdr.pc \
        --replace '=''${prefix}//' '=/' \
        --replace '=''${exec_prefix}//' '=/'
    '';

    meta = with lib; {
      homepage = "https://github.com/jketterl/csdr";
      description = "A simple DSP library and command-line tool for Software Defined Radio";
      license = licenses.gpl3Only;
      platforms = platforms.unix;
      broken = stdenv.isDarwin;
      maintainers = teams.c3d2.members;
    };
  };

  pycsdr-eti = buildPythonPackage rec {
    pname = "pycsdr-eti";
    version = "0.0.11";
    format = "setuptools";

    src = fetchFromGitHub {
      owner = "luarvique";
      repo = "pycsdr-eti";
      rev = version;
      hash = "sha256-pjY5sxHvuDTUDxpdhWk8U7ibwxHznyywEqj1btAyXBE=";
    };

    postPatch = ''
      substituteInPlace setup.py \
        --replace ', "fftw3"' ""
    '';

    propagatedBuildInputs = [pycsdr];
    buildInputs = [csdr-eti csdr];
    NIX_CFLAGS_COMPILE = [
      "-I${pycsdr}/include/${python.libPrefix}"
    ];

    # has no tests
    doCheck = false;
    pythonImportsCheck = ["csdreti"];

    meta = {
      homepage = "https://github.com/jketterl/pycsdr";
      description = "bindings for the csdr library";
      license = lib.licenses.gpl3Only;
      maintainers = lib.teams.c3d2.members;
    };
  };

  pycsdr = buildPythonPackage rec {
    pname = "pycsdr";
    version = "0.18.23";
    format = "setuptools";

    src = fetchFromGitHub {
      owner = "luarvique";
      repo = "pycsdr";
      rev = version;
      hash = "sha256-NjRBC7bhq2bMlRI0Q8bcGcneD/HlAO6l/0As3/lk4e8=";
    };

    buildInputs = [csdr];

    # has no tests
    doCheck = false;
    pythonImportsCheck = ["pycsdr"];

    meta = {
      homepage = "https://github.com/jketterl/pycsdr";
      description = "bindings for the csdr library";
      license = lib.licenses.gpl3Only;
      maintainers = lib.teams.c3d2.members;
    };
  };

  owrx_connector = stdenv.mkDerivation rec {
    pname = "owrx_connector";
    version = "0.6.5";

    src = fetchFromGitHub {
      owner = "luarvique";
      repo = pname;
      rev = version;
      sha256 = "sha256-e0VEv9t4gVDxJEbDJm1aKSJeqlmhT/QimC3x4JJ6ke8=";
    };

    nativeBuildInputs = [
      cmake
      ninja
      pkg-config
    ];

    buildInputs = [
      libsamplerate
      fftwFloat
      csdr
      rtl-sdr
      soapysdr-with-plugins
    ];

    meta = with lib; {
      homepage = "https://github.com/jketterl/owrx_connector";
      description = "A set of connectors that are used by OpenWebRX to interface with SDR hardware";
      license = licenses.gpl3Only;
      platforms = platforms.unix;
      maintainers = teams.c3d2.members;
    };
  };
in
  buildPythonApplication rec {
    pname = "openwebrxplus";
    version = "1.2.49";

    src = fetchFromGitHub {
      owner = "luarvique";
      repo = "openwebrx";
      rev = version;
      sha256 = "sha256-QHgt0JGV4E8vOZpY3UwxbtBV38NZBXNrc2asYbHjEqo=";
    };
    pyproject = true;
    build-system = [ setuptools ];

    propagatedBuildInputs = [
      pycsdr
      pycsdr-eti
      pydigiham
      js8py
      owrx_connector
      soapysdr-with-plugins
    ];

    buildInputs = [
      direwolf
      sox
      wsjtx
      codecserver
    ];

    pythonImportsCheck = ["csdr" "owrx" "test"];

    passthru = {
      inherit js8py owrx_connector pycsdr csdr;
    };

    meta = with lib; {
      homepage = "https://github.com/luarvique/openwebrx";
      description = "A simple DSP library and command-line tool for Software Defined Radio";
      mainProgram = "openwebrx";
      license = licenses.gpl3Only;
      maintainers = teams.c3d2.members;
    };
  }
