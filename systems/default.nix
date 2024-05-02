{inputs}: let
  # The purpose of this file is to set up the host module which allows assigning of the system, e.g. aarch64-linux and the builder used with less pain.
  lib = inputs.self.lib.nixlib;
  inherit (inputs.self.lib) meta std Std;
  inherit (lib.modules) evalModules;
  inherit (std) set;
  hostConfigs = set.map (name: path:
    evalModules {
      modules = [
        path
        meta.modules.system
      ];
      specialArgs = {
        inherit name inputs std Std meta;
        inherit (inputs.self.lib) gensokyo-zone;
      };
    })
  (set.map (_: c: c) meta.systems);
  processHost = name: cfg: let
    host = cfg.config;
  in
    set.optional (host.type != null) {
      deploy.nodes.${name} = host.deploy;

      "${host.folder}Configurations".${name} = host.built;
    };
in
  {
    systems = hostConfigs;
  }
  // set.merge (set.mapToValues processHost hostConfigs)
