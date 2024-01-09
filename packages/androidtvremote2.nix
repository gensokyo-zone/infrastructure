{ lib
, buildPythonPackage
, fetchFromGitHub
, aiofiles
, cryptography
, protobuf
, setuptools
, pytestCheckHook
}:

buildPythonPackage rec {
  pname = "androidtvremote2";
  version = "0.0.13";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "tronikos";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-+9VVUIvM//Fxv1a/+PAKWSQE8/TgBZzeTisgMqj6KPU=";
  };

  nativeBuildInputs = [
    setuptools
  ];

  propagatedBuildInputs = [
    aiofiles
    cryptography
    protobuf
  ];

  checkInputs = [
    pytestCheckHook
  ];

  pythonImportsCheck = [
    "androidtvremote2"
  ];
}
