{ depot, lib, config, ... }: with lib; {
config = {
    deploy.targets.infra = {
      tf = {
        resources.athame = {
          provider = "null";
          type = "resource";
          connection = {
            port = 62954;
            host = "athame.kittywit.ch";
          };
        };
      };
    };
    network.nodes.athame = {
      imports = lib.hostImport {
        hostName = "athame";
        inherit (depot) profiles;
      };
      networking = {
        hostName = "athame";
      };
    };
  };
}
