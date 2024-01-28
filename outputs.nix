{inputs}: let
  patchedInputs = import ./patchedInputs.nix {inherit inputs;};
  inherit
    (import ./overlays {
      inputs = patchedInputs;
    })
    pkgs
    ;
  inherit (inputs.nixpkgs) lib;
  tree = import ./tree.nix {
    inherit pkgs;
    inputs = patchedInputs;
  };
  systems = import ./systems {
    inherit inputs lib std pkgs;
    tree = tree.impure;
  };
  shells =
    inputs.flake-utils.lib.eachDefaultSystem
    (system: rec {
      devShells.default = import ./devShell.nix {inherit system inputs;};
    });
  std = import ./std.nix {inherit inputs;};
  inherit (std) set;
  checks = set.map (_: deployLib: deployLib.deployChecks inputs.self.deploy) inputs.deploy-rs.lib;
in
  {
    inherit tree std lib checks;
    inputs = patchedInputs;
    legacyPackages = pkgs;
  }
  // systems
  // shells
