final: prev: let
in {
  barcodebuddy = final.callPackage ../packages/barcodebuddy {};
  barcodebuddy-scanner = final.callPackage ../packages/barcodebuddy/scanner.nix {
    php = final.php83;
  };
  barcodebuddy-scanner-python = final.callPackage ../packages/barcodebuddy/scanner-python.nix {
    php = final.php83;
  };
}
