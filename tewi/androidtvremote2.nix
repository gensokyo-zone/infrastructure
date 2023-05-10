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
  version = "0.0.8";
  format = "pyproject";

  src = fetchFromGitHub {
    owner = "tronikos";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-R2KXInaWzaBk0KNDsuCLxI/ZY84viqX+7YJOpLsDirc=";
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
