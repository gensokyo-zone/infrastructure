{ buildPlugin
, python3Packages
, fetchFromGitHub
}: let
  version = "1.3.4";
in buildPlugin {
  pname = "OctoPrint-Octorant";
  inherit version;

  src = fetchFromGitHub {
    owner = "bchanudet";
    repo = "OctoPrint-Octorant";
    rev = version;
    sha256 = "sha256-gP79zlJ8gdtpddXOJIMhouSbwXnrSf+c1bURkN/7jvw=";
  };

  propagatedBuildInputs = with python3Packages; [
    pillow
  ];

  meta = {
    homepage = "https://github.com/bchanudet/OctoPrint-Octorant";
  };
}
