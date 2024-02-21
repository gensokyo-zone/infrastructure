{
  inputs,
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault mkForce;
  inherit (lib.attrsets) attrNames attrValues filterAttrs mapAttrs' nameValuePair;
  inherit (inputs.self.lib.lib) unmerged;
  cfg = config.services.github-runners;
  nixosConfig = config;
  enabledRunners = filterAttrs (_: runner: runner.enable) cfg;
  runnerModule = { config, ... }: {
    options = with lib.types; {
      networkNamespace.name = mkOption {
        type = nullOr str;
        default = null;
      };
      serviceSettings = mkOption {
        type = unmerged.type;
        default = { };
      };
    };
    config = {
      replace = mkIf config.ephemeral (mkDefault true);
      serviceSettings = mkIf (config.networkNamespace.name != null) {
        networkNamespace = {
          name = mkDefault config.networkNamespace.name;
          afterOnline = mkDefault true;
        };
        restartTriggers = [
          config.ephemeral
          config.url
          config.name
          config.runnerGroup
          config.extraLabels
          config.noDefaultLabels
          config.user
          config.group
          config.workDir
          "${config.package}"
          config.extraPackages
          config.nodeRuntimes
          (attrNames config.extraEnvironment)
          (attrValues config.extraEnvironment)
        ];
      };
      serviceOverrides = mkIf (config.user != null || config.group != null) {
        DynamicUser = mkForce true;
      };
    };
  };
in {
  options = with lib.types; {
    services.github-runners = mkOption {
      type = attrsOf (submodule runnerModule);
    };
  };
  config = {
    systemd.services = mapAttrs' (name: runner: nameValuePair "github-runner-${name}" (
      unmerged.merge runner.serviceSettings
    )) enabledRunners;
  };
}
