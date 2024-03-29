{
  description = "kat's nixfiles";
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    arcexprs = {
      url = "github:arcnmx/nixexprs/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    std = {
      url = "github:chessai/nix-std";
    };
    ci = {
      url = "github:arcnmx/ci/v0.7";
      flake = false;
    };
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    nur.url = "github:nix-community/nur/master";
    flake-utils.url = "github:numtide/flake-utils";
    flakelib = {
      url = "github:flakelib/fl";
      inputs.std.follows = "std-fl";
    };
    std-fl = {
      url = "github:flakelib/std";
      inputs.nix-std.follows = "std";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tree = {
      url = "github:kittywitch/tree";
      inputs.std.follows = "std";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs/master";
      inputs = {
        flake-compat.follows = "flake-compat";
        nixpkgs.follows = "nixpkgs";
        utils.follows = "flake-utils";
      };
    };
    systemd2mqtt = {
      url = "github:arcnmx/systemd2mqtt";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flakelib.follows = "flakelib";
      };
    };
    website = {
      url = "github:gensokyo-zone/website";
      inputs = {
        nixpkgs.follows = "nixpkgs";
        flakelib.follows = "flakelib";
      };
    };
    barcodebuddy = {
      url = "github:Forceu/barcodebuddy/v1.8.1.7";
      flake = false;
    };
  };
  nixConfig = {
    extra-substituters = [
      "https://arc.cachix.org"
      "https://gensokyo-infrastructure.cachix.org"
    ];
    extra-trusted-public-keys = [
      "arc.cachix.org-1:DZmhclLkB6UO0rc0rBzNpwFbbaeLfyn+fYccuAy7YVY="
      "gensokyo-infrastructure.cachix.org-1:CY6ChfQ8KTUdwWoMbo8ZWr2QCLMXUQspHAxywnS2FyI="
    ];
  };

  outputs = inputs: import ./outputs.nix {inherit inputs;};
  /*
    outputs = {
    self,
    nixpkgs,
    flake-utils,
    ...
  } @ inputs: let
    providedSystems =
      flake-utils.lib.eachDefaultSystem
      (system: rec {
        devShells.default = import ./devShell.nix {inherit system inputs;};
        legacyPackages = import ./meta.nix {inherit system inputs;};
        inherit (legacyPackages.outputs) packages;
      });
  in
    providedSystems
    // {
      nixosConfigurations = builtins.mapAttrs (_: config:
        config
        // {
          inherit config;
        })
      self.legacyPackages.x86_64-linux.network.nodes;
    };
  */
}
