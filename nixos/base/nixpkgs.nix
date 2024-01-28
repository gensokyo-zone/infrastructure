{
  inputs,
  ...
}: {
  nixpkgs = {
    overlays = [
      (import ../../overlays/local)
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
