{inputs, ...}: {
  nixpkgs = {
    overlays = [
      inputs.arcexprs.overlays.default
    ];
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
    };
  };
}
