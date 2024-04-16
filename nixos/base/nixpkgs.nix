{inputs, ...}: let
  inherit (inputs.self) overlays;
in {
  nixpkgs = {
    overlays = [
      inputs.arcexprs.overlays.default
      overlays.default
      overlays.unifi
    ];
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
    };
  };
}
