{
  inputs,
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.attrsets) filterAttrs mapAttrs' nameValuePair;
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
      serviceSettings = mkIf (config.networkNamespace.name != null) {
        networkNamespace = {
          name = mkDefault config.networkNamespace.name;
          afterOnline = mkDefault true;
        };
      };
      serviceOverrides = mkIf (config.user != null && nixosConfig.users.users ? ${config.user}) {
        DynamicUser = false;
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
