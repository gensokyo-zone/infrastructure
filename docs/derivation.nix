{
  lib,
  asciidoctor,
  stdenvNoCC,
  self,
}: let
  inherit (lib.strings) hasSuffix;
  src = lib.cleanSourceWith {
    name = "genso-docs-src";
    src = ./.;
    filter = path: type:
      (hasSuffix ".adoc" path || baseNameOf path == "docinfo.html")
      || type == "directory";
  };
in stdenvNoCC.mkDerivation {
  pname = "genso-docs";
  version = "dev";
  inherit src;

  ASCIIDOCTOR_OPTS = [
    "-a" "docinfo=shared"
  ];

  nativeBuildInputs = [ asciidoctor ];
  passAsFile = [ "buildCommand" ];
  buildCommand = ''
    install -d "$out"
    ASCIIDOCTOR_SRCS=(
      $(find "$src" -type f -name '*.adoc' -not -path "$src/inc/*")
    )
    asciidoctor \
      $ASCIIDOCTOR_OPTS \
      -a docinfodir="$src/" \
      -a inc="$src/_inc/" \
      -b html -R "$src" -D "$out" "''${ASCIIDOCTOR_SRCS[@]}"
  '';
}
