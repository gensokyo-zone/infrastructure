{
  pkgs,
  inputs,
  lib,
  meta,
  config,
  ...
}@metaArgs: let
/*
  This module:
* Makes hosts nixosModules.
* Manages module imports and specialArgs.
* Builds network.nodes.
*/
  enableNixosBuilder = false;
in with lib; {
  options.network = {
    nixos = {
      extraModules = mkOption {
        type = types.listOf types.unspecified;
        default = [];
      };
      specialArgs = mkOption {
        type = types.attrsOf types.unspecified;
        default = {};
      };
      modulesPath = mkOption {
        type = types.path;
        default = toString (pkgs.path + "/nixos/modules");
      };
      builder = mkOption {
        type = types.unspecified;
      };
    };
    nodes = let
      nixosModule = {
        name,
        config,
        meta,
        modulesPath,
        lib,
        ...
      }:
        with lib; {
          options = {
            nixpkgs.crossOverlays = mkOption {
              type = types.listOf types.unspecified;
              default = [];
            };
          };
          config = {
            nixpkgs = {
              system = mkDefault "x86_64-linux";
              pkgs = let
                pkgsReval = import pkgs.path {
                  inherit (config.nixpkgs) localSystem crossSystem crossOverlays;
                  inherit (pkgs) overlays config;
                };
              in
                mkDefault (
                  if config.nixpkgs.config == pkgs.config && config.nixpkgs.system == pkgs.targetPlatform.system
                  then pkgs
                  else pkgsReval
                );
            };
          };
        };
      nixosType = let
        baseModules = import (config.network.nixos.modulesPath + "/module-list.nix");
      in
        types.submoduleWith {
          modules =
            baseModules
            ++ singleton nixosModule
            ++ config.network.nixos.extraModules;

          specialArgs =
            {
              inherit baseModules;
              inherit (config.network.nixos) modulesPath;
            }
            // config.network.nixos.specialArgs;
        };
    in
      mkOption {
        type = types.lazyAttrsOf (
          if enableNixosBuilder then types.unspecified else nixosType
        );
        default = {};
      };
  };
  config.network = {
    nixos = {
      extraModules = [
        meta.modules.nixos
      ];
      specialArgs = {
        inherit (config.network) nodes;
        inherit inputs meta pkgs;
      };
      builder = mkOptionDefault ({
        pkgs ? metaArgs.pkgs,
        system ? pkgs.system,
        lib ? if args ? pkgs then pkgs.lib else metaArgs.lib,
        nixosSystem ? import (pkgs.path + "/nixos/lib/eval-config.nix"),
        baseModules ? import (modulesPath + "/module-list.nix"),
        modulesPath ? toString (pkgs.path + "/nixos/modules"),
        specialArgs ? config.network.nixos.specialArgs,
        extraModules ? config.network.nixos.extraModules,
        imports ? [ ],
        name,
        ...
      }@args: let
        args' = builtins.removeAttrs args [
          "extraModules" "specialArgs" "modulesPath" "baseModules" "lib" "pkgs" "system" "imports" "name"
        ];
        c = nixosSystem ({
          inherit lib baseModules extraModules pkgs system;
          modules = imports;
          specialArgs =
            {
              inherit baseModules name;
              inherit (config.network.nixos) modulesPath;
            }
            // config.network.nixos.specialArgs;
        } // args');
      in if enableNixosBuilder then c.config else {
        inherit imports;
      });
    };
  };
}
