final: prev: let
  inherit (final) lib;
in {
  minecraft-bedrock-server-libCrypto = let
    inherit (final) minecraft-bedrock-server;
  in minecraft-bedrock-server.stdenv.mkDerivation {
    pname = "${minecraft-bedrock-server.pname}-libcrypto";
    inherit (minecraft-bedrock-server) version src sourceRoot;
    nativeBuildInputs = with final; [
      autoPatchelfHook
      curl
      gcc-unwrapped
      openssl
      unzip
    ];
    installPhase = ''
      install -m755 -D libCrypto.so  $out/lib/libCrypto.so
    '';
    fixupPhase = ''
      autoPatchelf $out/lib/libCrypto.so
    '';
    meta.broken = true;
  };

  minecraft-bedrock-server-patchdebug = let
    # https://github.com/minecraft-linux/server-modloader/tree/master?tab=readme-ov-file#getting-mods-to-work-on-newer-versions-116
    python = final.python3.withPackages (p: [ p.lief ]);
    script = ''
      import lief
      import sys

      lib_symbols = lief.parse(sys.argv[1])
      for s in filter(lambda e: e.exported, lib_symbols.static_symbols):
          lib_symbols.add_dynamic_symbol(s)
      lib_symbols.write(sys.argv[2])
    '';
    name = "minecraft-bedrock-server-patchdebug";
  in final.writeTextFile {
    name = "${name}.py";
    destination = "/bin/${name}";
    executable = true;
    text = ''
      #!${lib.getExe python}
      ${script}
    '';
    meta.mainProgram = name;
  };

  minecraft-bedrock-server-patchelf = prev.patchelf.overrideDerivation (old: {
    postPatch = ''
      substituteInPlace src/patchelf.cc \
        --replace "32 * 1024 * 1024" "512 * 1024 * 1024"
    '';
  });

  minecraft-bedrock-server = final.callPackage ../packages/minecraft-bedrock.nix { };
}
