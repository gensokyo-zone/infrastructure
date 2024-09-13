{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.attrsets) mapAttrsToList;
  cfgs = config.services.wyoming;
in {
  config = {
    networking.firewall.interfaces.lan.allowedTCPPorts = let
      mkServerPort = _: server: mkIf (server.enable && server ? port) server.port;
      mkServicePorts = name: cfg:
        mapAttrsToList mkServerPort
        cfg.servers
        or {
          ${name} = cfg;
        };
    in
      mkMerge (mapAttrsToList mkServicePorts cfgs);
  };
}
