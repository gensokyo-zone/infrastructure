{
  inputs,
  system,
  ...
}: let
  pkgs = import ./overlays {inherit inputs system;}; # A local import of nixpkgs without patching.
in
  inputs
          // {
  nixpkgs = pkgs.applyPatches {
    name = "nixpkgs";
    src = inputs.nixpkgs;
    patches = [
      # https://github.com/NixOS/nixpkgs/pull/275896
      (pkgs.fetchpatch {
        url = "https://github.com/NixOS/nixpkgs/pull/275896.patch";
        sha256 = "sha256-boJLCdgamzX0fhLifdsxsFF/f7oXZwWJ7+WAkcA2GBg=";
      })
    ];
  };
}
