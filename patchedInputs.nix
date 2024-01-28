{
  inputs,
  system ? builtins.currentSystem or "x86_64-linux",
  ...
}: let
  pkgs = import inputs.nixpkgs {
    inherit system;
    config.allowUnfree = true;
  };
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
