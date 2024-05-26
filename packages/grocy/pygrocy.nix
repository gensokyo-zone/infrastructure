{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  backports-zoneinfo,
  deprecation,
  pydantic,
  requests,
  responses,
  pre-commit,
  isort,
  vcrpy,
  pytest,
  pytest-recording,
  pytest-mock,
  pythonOlder,
  # requires an instance of grocy api running...
  doCheckGrocy ? false,
}: let
  inherit (lib.lists) optional optionals;
  inherit (lib.strings) optionalString;
in
  buildPythonPackage rec {
    pname = "pygrocy";
    version = "2.1.0";
    format = "setuptools";

    src = fetchFromGitHub {
      owner = "SebRut";
      repo = "pygrocy";
      rev = "v${version}";
      hash = "sha256-ijwcdWMeBnYPhrNYt/IxucPvzc+0InudLxJSMVwulNw=";
    };

    postPatch = optionalString (!doCheckGrocy) ''
      rm test/test_grocy.py
    '';

    propagatedBuildInputs =
      [
        requests
        deprecation
        pydantic
      ]
      ++ optional (pythonOlder "3.9") backports-zoneinfo;

    pythonImportsCheck = [
      "pygrocy"
    ];

    checkInputs =
      [
        pytest
        pytest-recording
        pytest-mock
      ]
      ++ optionals doCheckGrocy [
        responses
        pre-commit
        isort
        vcrpy
      ];

    meta = {
      homepage = "https://github.com/SebRut/pygrocy";
      license = lib.licenses.mit;
      broken = pythonOlder "3.8";
    };
  }
