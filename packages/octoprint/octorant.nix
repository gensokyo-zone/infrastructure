{ buildPlugin
, python3Packages
, fetchFromGitHub
}: let
  pname = "OctoPrint-Octorant";
  version = "1.3.4";
in buildPlugin {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "bchanudet";
    repo = pname;
    rev = version;
    sha256 = "sha256-gP79zlJ8gdtpddXOJIMhouSbwXnrSf+c1bURkN/7jvw=";
  };

  patches = [
    ./octorant-timelapse-uri.patch
  ];

  propagatedBuildInputs = with python3Packages; [
    pillow
  ];

  meta = {
    homepage = "https://github.com/bchanudet/OctoPrint-Octorant";
  };
}
