{
  lib,
  config,
  channels,
  env,
  ...
}:
with lib; {
  imports = [ ./common.nix ];
  config = {
    name = "nodes";

    jobs = let
      enabledSystems = filterAttrs (_: system: system.ci.enable) channels.nixfiles.lib.gensokyo-zone.systems;
      mkSystemJob = name: system: nameValuePair "${name}" {
        tasks.system = {
          inputs = channels.nixfiles.nixosConfigurations.${name}.config.system.build.toplevel;
          warn = system.ci.allowFailure;
        };
      };
      systemJobs = mapAttrs' mkSystemJob enabledSystems;
    in {
      packages = { ... }: {
        imports = [ ./packages.nix ];
      };
    } // systemJobs;
  };
}
