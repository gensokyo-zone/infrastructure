{ stdenv
, fetchurl
, minecraft-bedrock-server-patchelf
, minecraft-bedrock-server-patchdebug
#, minecraft-bedrock-server-libCrypto
, autoPatchelfHook
, curl, gcc-unwrapped, openssl, unzip
}: stdenv.mkDerivation rec {
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
  installPhase = ''
    install -m755 -D bedrock_server $out/bin/bedrock_server
    rm bedrock_server
    rm server.properties
    mkdir -p $out/var
    cp -a . $out/var/lib
  '';
  fixupPhase = ''
    autoPatchelf $out/bin/bedrock_server
  '';
  dontStrip = true;
}
