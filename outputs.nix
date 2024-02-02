{inputs}: let
  tree = import ./tree.nix {
    inherit inputs;
  };
  systems = import ./systems {
    inherit inputs;
    tree = tree.impure;
  };
  outputs =
    inputs.flake-utils.lib.eachDefaultSystem
    (system: let
      legacyPackages = inputs.self.legacyPackages.${system};
      inherit (legacyPackages) pkgs;
    in {
      devShells = import ./devShells.nix {inherit system inputs;};
      packages = import ./packages {inherit system inputs;};
      legacyPackages = {
        inherit (import ./overlays {inherit system inputs;}) pkgs;
        patchedNixpkgs = pkgs.applyPatches {
          name = "nixpkgs";
          src = inputs.nixpkgs;
          patches = [
            inputs.nixpkgs-patch-k8s-pki
          ];
        };
        deploy-rs = let
          deployLib =
            inputs.deploy-rs.lib.${system}
            or rec {
              activate = throw "deploy-rs.lib.${system} unsupported";
              setActivate = activate;
              deployChecks = _: {};
            };
          deploy-rs =
            inputs.deploy-rs.packages.${system}.default
            or pkgs.${system}.deploy-rs.deploy-rs
            or pkgs.${system}.deploy-rs
            or {
              name = "deploy-rs";
              outPath = throw "deploy-rs.packages.${system} unsupported";
              meta = {};
            };
        in {
          inherit (deploy-rs) name outPath meta;
          inherit (deployLib) activate setActivate deployChecks;
        };
      };
      checks = legacyPackages.deploy-rs.deployChecks inputs.self.deploy;
    });
in {
  inherit (outputs) devShells legacyPackages packages checks;
  inherit (systems) deploy nixosConfigurations;
  lib = {
    std = import ./std.nix {inherit inputs;};
    nixlib = inputs.nixpkgs.lib;
    inherit tree;
  };
}
