final: prev: let
  inherit (final) lib;
in {
  ollama-mmap = prev.ollama.overrideAttrs (old: {
    postPatch =
      ''
        substituteInPlace api/types.go \
          --replace 'UseMMap:   nil,' 'UseMMap:   &[]bool{true}[0],'
      ''
      + old.postPatch or "";
    doCheck = false;
  });
  ollama-cuda = final.ollama.override {
    acceleration = "cuda";
  };
  ollama-rocm = final.ollama.override {
    acceleration = "rocm";
  };

  nextjs-ollama-llm-ui-develop = prev.nextjs-ollama-llm-ui.overrideAttrs (old: rec {
    version = "2024-08-27";
    name = "${old.pname}-${version}";

    patches = let
      packageRoot = final.path + "/pkgs/by-name/ne/nextjs-ollama-llm-ui";
    in [
      #(packageRoot + "/0001-update-nextjs.patch")
      (packageRoot + "/0002-use-local-google-fonts.patch")
      #(packageRoot + "/0003-add-standalone-output.patch")
    ];

    src = old.src.override {
      rev = "7c8eb67c3eb4f18eaa9bde8007147520e3261867";
      hash = "sha256-Ym5RL+HbOmOM6CLYFf0JMsM+jMcFyCUAm1bD/CXeE+I=";
    };
    npmDeps = final.fetchNpmDeps {
      name = "${name}-npm-deps";
      hash = "sha256-8VRBUNUDwSQYhRJjqaKP/RwUgFKKoiQUPjGDFw37Wd4=";
      inherit src patches;
    };
  });
}
