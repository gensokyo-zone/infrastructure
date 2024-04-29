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

  unzipMcpack = let
    f = { stdenvNoCC, unzip, writeText }: stdenvNoCC.mkDerivation {
      name = "unzip-mcpack";
      propagatedBuildInputs = [ unzip ];
      dontUnpack = true;
      setupHook = writeText "mcpack-setup-hook.sh" ''
        unpackCmdHooks+=(_tryUnzipMcpack)
        _tryUnzipMcpack() {
          if ! [[ "$curSrc" =~ \.mcpack$ ]]; then return 1; fi

          LANG=en_US.UTF-8 unzip -qq "$curSrc"
        }
      '';
    };
  in final.callPackage f { };
  mkMinecraftBedrockServerAddon = let
    argNames = [ "mcpackModules" "mcpackVersion" "mcpackId" ];
    f = { stdenvNoCC, unzipMcpack, minecraft-bedrock-server, lib }: {
      src,
      pname,
      version,
      mcpackVersion ? version,
      mcVersion ? null,
      mcpackId,
      mcpackModules ? [ ],
      mcpackDir ? pname,
      mcpackType ? "behavior_packs",
      ...
    }@args: let
      inherit (lib.strings) optionalString splitString;
      inherit (minecraft-bedrock-server) dataDir;
    in stdenvNoCC.mkDerivation (removeAttrs args argNames // {
      inherit dataDir mcpackType mcpackDir;
      version = version + optionalString (mcVersion != null) "-${mcVersion}";
      nativeBuildInputs = args.nativeBuildInputs or [ ] ++ [
        unzipMcpack
      ];
      installPhase = args.installPhase or ''
        install -d "$out$dataDir/$mcpackType/$mcpackDir"
        cp -a ./* "$out$dataDir/$mcpackType/$mcpackDir/"

        install ./manifest.json $manifest
      '';
      outputs = [ "out" "manifest" ];
      passthru = args.passthru or { } // {
        minecraft-bedrock = args.passthru.minecraft-bedrock or { } // {
          pack = args.passthru.minecraft-bedrock.pack or { } // {
            pack_id = mcpackId;
            modules = mcpackModules;
            version = splitString "." mcpackVersion;
            type = mcpackType;
            dir = mcpackDir;
            subPath = "${dataDir}/${mcpackType}/${mcpackDir}";
          };
        };
      };
    });
  in final.callPackage f { };

  minecraft-bedrock-addons = {
    definitive-tree-capitator-bh = final.mkMinecraftBedrockServerAddon {
      pname = "definitive-tree-capitator-bh";
      version = "1.0.0";
      mcpackId = "b3538a6c-3e42-400a-9ed0-5ec1670b796c";
      mcpackVersion = "1.0.0";
      mcVersion = "1.20.20";
      src = final.fetchurl {
        url = "https://mediafilez.forgecdn.net/files/5214/136/Definitive%20Tree%20Capitator%20BH.mcpack";
        sha256 = "941564d65386fd2701dfe017408d8c1d5b6d6a90a017e60b7ef9f6ff6de7b51a";
      };
    };
    definitive-tree-capitator-rs = final.mkMinecraftBedrockServerAddon {
      pname = "definitive-tree-capitator-rs";
      version = "1.0.0";
      mcpackId = "e01dd561-a1d9-45d0-b6ad-cd3858b93fe7";
      mcpackVersion = "1.0.0";
      mcVersion = "1.13.0";
      src = final.fetchurl {
        url = "https://mediafilez.forgecdn.net/files/5214/134/Definitive%20Tree%20Capitator%20RS.mcpack";
        sha256 = "22c8ff1c85720052d9f2a0af1c205b5457a9bb806d65125cff3751fdbe22b864";
      };
    };
    true-tree-capitator-bp = final.mkMinecraftBedrockServerAddon {
      pname = "true-tree-capitator-bp";
      version = "1.2";
      mcpackVersion = "1.0.0";
      mcpackId = "4d0f6078-f2f9-415f-9848-b36b008127b4";
      mcVersion = "1.20.71";
      src = final.fetchurl {
        name = "Tree-capitator-BP-v1.2.mcpack";
        url = "https://mediafilez.forgecdn.net/files/5237/589/Tree%20capitator%20%5BBP%5D%20v1.2.mcpack";
        sha256 = "c4b702be4dd45707b66ef3cfda578695347caa6a43ead30c06dc17cd14a00040";
      };
      sourceRoot = ".";
    };
    true-tree-capitator-rp = final.mkMinecraftBedrockServerAddon {
      pname = "true-tree-capitator-rp";
      version = "1.2";
      mcpackVersion = "1.0.0";
      mcpackId = "811af5f4-929b-4d77-aed4-119486b6c0a0";
      mcVersion = "1.20.71";
      mcpackType = "resource_packs";
      src = final.fetchurl {
        name = "Tree-capitator-RP-v1.2.mcpack";
        url = "https://mediafilez.forgecdn.net/files/5237/590/Tree%20capitator%20%5BRP%5D%20v1.2.mcpack";
        sha256 = "66c850106c7fa1764b32f20c555c1bb5e7e6905f3cbea4b429ca076e7a4cc31f";
      };
      sourceRoot = ".";
    };
  };
}
