{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) taskchampion-sync-server;
  name.shortServer = mkDefault "task";
  upstreamName = "taskchampion'access";
in {
  config.services.nginx = {
    upstreams'.${upstreamName}.servers = {
      local = {
        enable = mkDefault taskchampion-sync-server.enable;
        addr = mkDefault "localhost";
        port = mkIf taskchampion-sync-server.enable (mkDefault taskchampion-sync-server.port);
      };
      service = {upstream, ...}: {
        enable = mkIf upstream.servers.local.enable (mkDefault false);
        accessService = {
          name = "taskchampion";
        };
      };
    };
    virtualHosts = let
      copyFromVhost = mkDefault "taskchampion";
      locations = {
        "/" = {
          proxy.enable = true;
        };
      };
    in {
      taskchampion = {
        inherit name locations;
        proxy.upstream = mkDefault upstreamName;
        vouch.enable = mkDefault true;
      };
      taskchampion'local = {
        inherit name locations;
        ssl.cert = {
          inherit copyFromVhost;
        };
        proxy = {
          inherit copyFromVhost;
        };
        local.enable = mkDefault true;
      };
    };
  };
}
