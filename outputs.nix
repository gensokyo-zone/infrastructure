{inputs}: let
  tree = import ./tree.nix {
    inherit inputs;
  };
  systems = import ./systems {
    inherit inputs;
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
        pkgs = let
          pkgs = import inputs.nixpkgs {
            inherit system;
            overlays = [
              inputs.self.overlays.default
              inputs.self.overlays.deploy-rs
              inputs.self.overlays.systemd2mqtt
              inputs.self.overlays.arc
            ];
            config = {
              allowUnfree = true;
            };
          };
          # see overlays/builders.nix
        in
          pkgs.__withSubBuilders;
        patchedNixpkgs = let
          patches = [
            ./packages/nixpkgs-keycloak-nullhostname.patch
          ];
          patchedNixpkgs = pkgs.applyPatches {
            name = "nixpkgs";
            src = inputs.nixpkgs;
            inherit patches;
          };
        in if patches != [] then patchedNixpkgs else pkgs;
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
  inherit (inputs.self.lib.lib) treeToModulesOutput;
in {
  inherit (outputs) devShells legacyPackages packages checks;
  inherit (systems) deploy nixosConfigurations;
  inherit (tree.impure) overlays;
  nixosModules = with tree.impure.modules;
    treeToModulesOutput extern.nixos
    // {
      inherit (nixos) barcodebuddy barcodebuddy-scanner minecraft-bedrock vouch;
      network = {
        __functor = network: _: {
          imports = [network.netgroups network.namespace network.resolve];
        };
        inherit (nixos.network) netgroups namespace resolve;
      };
      sssd = {
        __functor = sssd: _: {
          imports = [sssd.sssd sssd.pam];
        };
        inherit (nixos.sssd) sssd pam genso;
      };
    };
  homeModules = treeToModulesOutput tree.impure.modules.extern.home;
  miscModules = treeToModulesOutput tree.impure.modules.extern.misc;
  lib = import ./lib.nix {
    inherit tree inputs;
    inherit (systems) systems;
  };
}
