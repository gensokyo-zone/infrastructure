{ lib, minecraft-bedrock-server, stdenv, autoPatchelfHook, curl, gcc-unwrapped, unzip, openssl }: let
  inherit (lib.strings) versionAtLeast;
in stdenv.mkDerivation {
  pname = "${minecraft-bedrock-server.pname}-libcrypto";
  inherit (minecraft-bedrock-server) version src sourceRoot;
  nativeBuildInputs = [
    autoPatchelfHook
    curl
    gcc-unwrapped
    openssl
    unzip
  ];
  installPhase = ''
    install -m755 -D libCrypto.so $out/lib/libCrypto.so
  '';
  fixupPhase = ''
    autoPatchelf $out/lib/libCrypto.so
  '';
  meta.broken = versionAtLeast minecraft-bedrock-server.version "1.20";
}
