{
  config,
  access,
  ...
}: let
  nixosModule = {
    config,
    ...
  }: {
    config = {
      _module.args.access = access // {
        systemFor = hostName: if hostName == config.networking.hostName
          then config
          else access.systemFor hostName;
        systemForOrNull = hostName: if hostName == config.networking.hostName
          then config
          else access.systemForOrNull hostName;
      };
    };
  };
in {
  config = {
    network.nixos.extraModules = [
      nixosModule
    ];

    _module.args.access = {
      systemFor = hostName: config.network.nodes.${hostName};
      systemForOrNull = hostName: config.network.nodes.${hostName} or null;
    };
  };
}
