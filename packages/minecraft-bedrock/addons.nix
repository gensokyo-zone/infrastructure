{ lib, mkMinecraftBedrockServerAddon, fetchurl }: let
  inherit (lib.attrsets) mapAttrs;
  true-tree-capitator = {
    version = "1.2";
    mcpackVersion = "1.0.0";
    mcVersion = "1.20.71";
    sourceRoot = ".";
    meta.homepage = "https://www.curseforge.com/minecraft-bedrock/addons/tree-capitator";
  };
  true-tree-capitator-bp = true-tree-capitator // {
    pname = "true-tree-capitator-bp";
    mcpackId = "4d0f6078-f2f9-415f-9848-b36b008127b4";
    mcpackType = "behavior_packs";
    src = fetchurl {
      name = "Tree-capitator-BP-v1.2.mcpack";
      url = "https://mediafilez.forgecdn.net/files/5237/589/Tree%20capitator%20%5BBP%5D%20v1.2.mcpack";
      sha256 = "c4b702be4dd45707b66ef3cfda578695347caa6a43ead30c06dc17cd14a00040";
    };
    postPatch = ''
      substituteInPlace manifest.json \
        --replace "1.10.0-beta" "1.11.0-beta"
    '';
  };
  true-tree-capitator-rp = true-tree-capitator // {
    pname = "true-tree-capitator-rp";
    mcpackId = "811af5f4-929b-4d77-aed4-119486b6c0a0";
    mcpackType = "resource_packs";
    src = fetchurl {
      name = "Tree-capitator-RP-v1.2.mcpack";
      url = "https://mediafilez.forgecdn.net/files/5237/590/Tree%20capitator%20%5BRP%5D%20v1.2.mcpack";
      sha256 = "66c850106c7fa1764b32f20c555c1bb5e7e6905f3cbea4b429ca076e7a4cc31f";
    };
  };
  definitive-tree-capitator = {
    version = "1.0.0";
    mcpackVersion = "1.0.0";
    meta.homepage = "https://www.curseforge.com/minecraft-bedrock/addons/definitive-tree-capitator-addon";
  };
  definitive-tree-capitator-bh = definitive-tree-capitator // {
    pname = "definitive-tree-capitator-bh";
    mcpackId = "b3538a6c-3e42-400a-9ed0-5ec1670b796c";
    mcpackType = "behavior_packs";
    mcVersion = "1.20.20";
    src = fetchurl {
      url = "https://mediafilez.forgecdn.net/files/5214/136/Definitive%20Tree%20Capitator%20BH.mcpack";
      sha256 = "941564d65386fd2701dfe017408d8c1d5b6d6a90a017e60b7ef9f6ff6de7b51a";
    };
    patches = [
      ./definitive-tree-capitator-bh.patch
    ];
  };
  definitive-tree-capitator-rs = definitive-tree-capitator // {
    pname = "definitive-tree-capitator-rs";
    mcpackId = "e01dd561-a1d9-45d0-b6ad-cd3858b93fe7";
    mcpackType = "resource_packs";
    mcVersion = "1.13.0";
    src = fetchurl {
      url = "https://mediafilez.forgecdn.net/files/5214/134/Definitive%20Tree%20Capitator%20RS.mcpack";
      sha256 = "22c8ff1c85720052d9f2a0af1c205b5457a9bb806d65125cff3751fdbe22b864";
    };
  };
in mapAttrs (_: mkMinecraftBedrockServerAddon) {
  inherit
    true-tree-capitator-bp true-tree-capitator-rp
    definitive-tree-capitator-bh definitive-tree-capitator-rs
  ;
}
