{inputs, ...}: {
  nixpkgs = {
    overlays = [
      inputs.arcexprs.overlays.default
      (import ../../overlays/samba.nix)
    ];
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
    };
  };
}
