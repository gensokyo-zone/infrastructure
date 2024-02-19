{
  config,
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (gensokyo-zone.lib) unmerged;
  cfg = config.gensokyo-zone.nix;
  nixModule = {
    gensokyo-zone,
    nixosConfig,
    config,
    ...
  }: let
    inherit (gensokyo-zone.lib) unmerged domain;
  in {
    options = with lib.types; {
      enable = mkEnableOption "nix settings";
      cache = {
        arc.enable = mkEnableOption "arc cache";
        infrastructure.enable =
          mkEnableOption "gensokyo-infrastructure cache"
          // {
            default = true;
          };
      };
      builder = {
        enable = mkEnableOption "aya nixbld remote builder";
        domain = mkOption {
          type = str;
          default = "nixbld.${domain}";
        };
        protocol = mkOption {
          type = enum ["ssh" "ssh-ng"];
          default = "ssh";
        };
        ssh = {
          user = mkOption {
            type = str;
            default = "nixbld";
          };
          key = mkOption {
            type = nullOr path;
            default = null;
          };
        };
        jobs = mkOption {
          type = int;
          default = 16;
        };
        systems = mkOption {
          type = listOf str;
          default = ["x86_64-linux"];
        };
        features = mkOption {
          type = listOf str;
          default = ["nixos-test" "benchmark" "big-parallel" "kvm"];
        };
        setBuildMachine = mkOption {
          type = unmerged.types.attrs;
          default = {};
        };
      };
      setNixSettings = mkOption {
        type = unmerged.types.attrs;
        default = {};
      };
      setNixBuildMachines = mkOption {
        type = unmerged.type;
        default = [];
      };
    };
    config = {
      setNixSettings = mkMerge [
        (mkIf config.cache.arc.enable {
          extra-substituters = [
            "https://arc.cachix.org"
          ];
          extra-trusted-public-keys = [
            "arc.cachix.org-1:DZmhclLkB6UO0rc0rBzNpwFbbaeLfyn+fYccuAy7YVY="
          ];
        })
        (mkIf config.cache.infrastructure.enable {
          extra-substituters = [
            "https://gensokyo-infrastructure.cachix.org"
          ];
          extra-trusted-public-keys = [
            "gensokyo-infrastructure.cachix.org-1:CY6ChfQ8KTUdwWoMbo8ZWr2QCLMXUQspHAxywnS2FyI="
          ];
        })
      ];
      builder = {
        domain = mkIf nixosConfig.services.tailscale.enable (
          mkDefault
          "nixbld.tail.${domain}"
        );
        setBuildMachine = {
          hostName = config.builder.domain;
          protocol = config.builder.protocol;
          sshUser = config.builder.ssh.user;
          sshKey = config.builder.ssh.key;
          maxJobs = config.builder.jobs;
          systems = config.builder.systems;
          supportedFeatures = config.builder.features;
        };
      };
      setNixBuildMachines = mkIf config.builder.enable [
        (
          unmerged.mergeAttrs config.builder.setBuildMachine
        )
      ];
    };
  };
in {
  options.gensokyo-zone.nix = mkOption {
    type = lib.types.submoduleWith {
      modules = [nixModule];
      specialArgs = {
        inherit gensokyo-zone;
        inherit (gensokyo-zone) inputs;
        nixosConfig = config;
      };
    };
    default = { };
  };

  config = {
    nix = mkIf cfg.enable {
      settings = unmerged.mergeAttrs cfg.setNixSettings;
      buildMachines = unmerged.merge cfg.setNixBuildMachines;
    };
    lib.gensokyo-zone.nix = {
      inherit cfg nixModule;
    };
  };
}
