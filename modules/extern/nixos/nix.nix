{
  config,
  options,
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (gensokyo-zone.lib) unmerged mkAlmostOptionDefault;
  cfg = config.gensokyo-zone.nix;
  nixModule = {
    lib,
    gensokyo-zone,
    nixosConfig,
    nixosOptions,
    config,
    ...
  }: let
    inherit (gensokyo-zone.lib) unmerged domain;
    inherit (lib.modules) mkOptionDefault;
    inherit (nixosConfig.gensokyo-zone) access;
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
        cross = {
          aarch64 = mkEnableOption "qemu-aarch64";
          armv7l = mkEnableOption "qemu arm";
        };
        domain = mkOption {
          type = str;
          default = "nixbld.${domain}";
        };
        protocol = mkOption {
          type = enum ["ssh" "ssh-ng"];
          default = "ssh";
        };
        ssh = {
          commonKey =
            mkEnableOption "shared secret nixbld key"
            // {
              default = true;
            };
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
        type = unmerged.type;
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
        systems = mkMerge [
          (mkIf config.builder.cross.aarch64 (mkOptionDefault ["aarch64-linux"]))
          (mkIf config.builder.cross.armv7l (mkOptionDefault ["armv7l-linux"]))
        ];
        domain = mkMerge [
          (mkIf access.tail.enabled (mkAlmostOptionDefault "nixbld.tail.${domain}"))
          (mkIf access.local.enable (mkDefault "nixbld.local.${domain}"))
        ];
        ssh.key = let
          inherit (nixosConfig.sops) secrets;
        in
          mkIf (nixosOptions ? sops.secrets && secrets ? gensokyo-zone-nix-bld-key) (
            mkAlmostOptionDefault
            nixosConfig.sops.secrets.gensokyo-zone-nix-bld-key.path
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
        nixosOptions = options;
      };
    };
    default = {};
  };

  config = {
    nix = mkIf cfg.enable {
      settings = unmerged.merge cfg.setNixSettings;
      buildMachines = unmerged.merge cfg.setNixBuildMachines;
    };
    ${
      if options ? sops.secrets
      then "sops"
      else null
    }.secrets = let
      sopsFile = mkDefault ../secrets/nix.yaml;
    in
      mkIf cfg.enable {
        gensokyo-zone-nix-bld-key = mkIf cfg.builder.ssh.commonKey {
          inherit sopsFile;
        };
      };
    lib.gensokyo-zone.nix = {
      inherit cfg nixModule;
    };
  };
}
