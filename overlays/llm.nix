final: prev: let
  inherit (final) lib;
in {
  ollama-mmap = prev.ollama.overrideAttrs (old: {
    postPatch =
      ''
        substituteInPlace api/types.go \
          --replace-fail 'UseMMap:   nil,' 'UseMMap:   &[]bool{true}[0],'
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

  wyoming-openwakeword = let
    inherit (prev) wyoming-openwakeword;
    drv = prev.wyoming-openwakeword.override {
      python3Packages = final.python311Packages;
    };
    isPython312 = lib.versionAtLeast final.python3Packages.python.version "3.12";
    isBroken = wyoming-openwakeword.version == "1.10.0" && isPython312;
  in
    if isBroken
    then drv
    else lib.warnIf isPython312 "wyoming-openwakeword override outdated" wyoming-openwakeword;
}
