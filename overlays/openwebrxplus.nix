final: prev: let
in {
  openwebrxplus = final.python3Packages.callPackage ../packages/openwebrxplus.nix {};
}