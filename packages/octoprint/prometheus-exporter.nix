{ buildPlugin
, python3Packages
, fetchFromGitHub
}: let
  version = "0.2.3";
in buildPlugin {
  pname = "OctoPrint-Prometheus-Exporter";
  inherit version;

  src = fetchFromGitHub {
    owner = "tg44";
    repo = "OctoPrint-Prometheus-Exporter";
    rev = version;
    sha256 = "sha256-pw5JKMWQNAkFkUADR2ue6R4FOmFIeapw2k5FLqJ6NQg=";
  };

  propagatedBuildInputs = with python3Packages; [
    prometheus-client
  ];

  patches = [
    ./prometheus-exporter-deregister.patch
  ];

  meta = {
    homepage = "https://github.com/tg44/OctoPrint-Prometheus-Exporter";
  };
}
