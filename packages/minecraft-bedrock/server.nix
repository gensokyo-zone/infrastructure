{
  stdenv,
  fetchurl,
  minecraft-bedrock-server-patchelf,
  minecraft-bedrock-server-patchdebug,
  #, minecraft-bedrock-server-libCrypto
  autoPatchelfHook,
  curl,
  gcc-unwrapped,
  openssl,
  unzip,
  lib,
}: let
  inherit (lib) licenses;
in
  stdenv.mkDerivation rec {
    pname = "minecraft-bedrock-server";
    version = "1.20.80.05";
    src = fetchurl {
      url = "https://minecraft.azureedge.net/bin-linux/bedrock-server-${version}.zip";
      sha256 = "sha256-6vZx29FOXRR7Rzx82Axo3a/Em+9cpK7Hj3cuDRnW9+8=";
    };
    sourceRoot = ".";
    nativeBuildInputs = [
      minecraft-bedrock-server-patchelf
      minecraft-bedrock-server-patchdebug
      autoPatchelfHook
      curl
      gcc-unwrapped
      #minecraft-bedrock-server-libCrypto
      openssl
      unzip
    ];
    buildPhase = ''
      minecraft-bedrock-server-patchdebug bedrock_server_symbols.debug bedrock_server_symbols_patched.debug
    '';
    dataDir = "/var/lib/minecraft-bedrock";
    installPhase = ''
      install -m755 -D bedrock_server $out/bin/bedrock_server
      install -d $out$dataDir
      cp -a definitions behavior_packs resource_packs config env-vars *.json *.debug *.properties $out$dataDir/
    '';
    fixupPhase = ''
      autoPatchelf $out/bin/bedrock_server
    '';
    dontStrip = true;

    meta = {
      platforms = ["x86_64-linux"];
      license = licenses.unfree;
      mainProgram = "bedrock_server";
    };
  }
