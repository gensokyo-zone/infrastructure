final: prev: let
in {
  openwebrxplus = final.python311Packages.callPackage ../packages/openwebrxplus.nix {};
}
