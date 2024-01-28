{
  inputs,
  tree,
  pkgs,
  lib,
  std,
  system ? builtins.currentSystem or "x86_64-linux",
  ...
}: let
  # The purpose of this file is to set up the host module which allows assigning of the system, e.g. aarch64-linux and the builder used with less pain.
  inherit (lib.modules) evalModules mkOptionDefault;
  inherit (std) string types optional set list;
  defaultSpecialArgs = {
    inherit inputs std;
    meta = tree;
  };
  hostModule = {
    config,
    machine,
    ...
  }: {
    options = let
      inherit (lib.types) str listOf attrs unspecified attrsOf nullOr;
      jsonType = (pkgs.${system}.formats.json {}).type;
      inherit (lib.options) mkOption;
    in {
      arch = mkOption {
        description = "Processor architecture of the host";
        type = str;
        default = "x86_64";
      };
      type = mkOption {
        description = "Operating system type of the host";
        type = str;
        default = "NixOS";
      };
      folder = mkOption {
        type = str;
        internal = true;
      };
      system = mkOption {
        type = str;
        internal = true;
      };
      modules = mkOption {
        type = listOf unspecified;
      };
      specialArgs = mkOption {
        type = attrs;
        internal = true;
      };
      builder = mkOption {
        type = unspecified;
        internal = true;
      };
      deploy = mkOption {
        type = nullOr jsonType;
      };
    };
    config = {
      deploy = {
        sshUser = mkOptionDefault "root";
        user = mkOptionDefault "root";
        sshOpts = mkOptionDefault ["-p" "${builtins.toString (builtins.head inputs.self.nixosConfigurations.${machine}.config.services.openssh.ports)}"];
        autoRollback = mkOptionDefault true;
        magicRollback = mkOptionDefault true;
        fastConnection = mkOptionDefault false;
        hostname = mkOptionDefault "${machine}.local.gensokyo.zone";
        profiles.system = {
          user = "root";
          path = inputs.deploy-rs.lib.${system}.activate.nixos inputs.self.nixosConfigurations.${machine};
        };
      };
      system = let
        kernel =
          {
            nixos = "linux";
            macos = "darwin";
            darwin = "darwin";
            linux = "linux";
          }
          .${string.toLower config.type};
      in "${config.arch}-${kernel}";
      folder =
        {
          nixos = "nixos";
          macos = "darwin";
          darwin = "darwin";
          linux = "linux";
        }
        .${string.toLower config.type};
      modules = with tree; [
        # per-OS modules
        tree.modules.${config.folder}
        # per-OS configuration
        tree.${config.folder}.base
      ];
      builder =
        {
          nixos = let
            lib = inputs.nixpkgs.lib.extend (self: super:
              import (inputs.arcexprs + "/lib") {
                inherit super;
                lib = self;
                isOverlayLib = true;
              });
            sys = args:
              lib.nixosSystem ({
                  inherit lib;
                }
                // args);
          in
            sys;
          darwin = inputs.darwin.lib.darwinSystem;
          macos = inputs.darwin.lib.darwinSystem;
        }
        .${string.toLower config.type};
      specialArgs =
        {
          name = machine;
          inherit machine;
          systemType = config.folder;
          inherit (config) system;
        }
        // defaultSpecialArgs;
    };
  };
  hostConfigs = set.map (name: path:
    evalModules {
      modules = [
        hostModule
        path
      ];
      specialArgs =
        defaultSpecialArgs
        // {
          inherit name;
          machine = name;
        };
    })
  (set.map (_: c: c) tree.systems);
  processHost = name: cfg: let
    host = cfg.config;
  in {
    deploy.nodes.${name} = host.deploy;

    "${host.folder}Configurations".${name} = host.builder {
      inherit (host) system modules specialArgs;
    };
  };
in
  set.merge (set.mapToValues processHost hostConfigs)
