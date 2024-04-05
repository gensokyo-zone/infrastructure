{inputs, ...}: {
  nixpkgs = {
    overlays = [
      inputs.arcexprs.overlays.default
      (import ../../overlays/barcodebuddy.nix)
      (import ../../overlays/samba.nix)
      (import ../../overlays/nginx.nix)
      (import ../../overlays/krb5.nix)
    ];
    config = {
      allowUnfree = true;
      permittedInsecurePackages = [
        "openssl-1.1.1w"
      ];
    };
  };
}
