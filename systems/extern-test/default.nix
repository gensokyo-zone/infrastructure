{
  inputs,
  lib,
  ...
}: let
  inherit (lib.modules) mkForce;
in {
  arch = "x86_64";
  type = "NixOS";
  modules = mkForce [
    ./nixos.nix
  ];
  builder = mkForce ({
    modules,
    system,
    specialArgs,
    ...
  }:
    inputs.nixpkgs.lib.nixosSystem {
      inherit modules system;
      specialArgs = {
        extern'test'inputs = specialArgs.inputs;
      };
    });
}
