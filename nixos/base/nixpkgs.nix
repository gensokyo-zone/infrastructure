{gensokyo-zone, ...}: let
  inherit (gensokyo-zone.self) overlays;
in {
  nixpkgs = {
    overlays = [
      gensokyo-zone.inputs.arcexprs.overlays.default
      overlays.default
    ];
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
    };
  };
}
