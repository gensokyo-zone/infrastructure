{ buildPlugin
, python3Packages
, fetchFromGitHub
}: let
  version = "2.0.0";
  pname = "OctoPrint-Queue";
in buildPlugin {
  inherit pname version;

  src = fetchFromGitHub {
    owner = "chennes";
    repo = pname;
    rev = "v${version}";
    sha256 = "sha256-uAG6GrUKXUdUTtzmjKWPiHxMa3ekvoLpSIvFMiJI+/8=";
  };

  propagatedBuildInputs = with python3Packages; [
  ];

  meta = {
    homepage = "https://github.com/chennes/OctoPrint-Queue";
  };
}
