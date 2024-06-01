{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) gatus;
  name.shortServer = mkDefault "status";
  upstreamName = "gatus'access";
in {
  config.services.nginx = {
    upstreams'.${upstreamName}.servers = {
      local = {
        enable = mkDefault gatus.enable;
        addr = mkDefault "localhost";
        port = mkIf gatus.enable (mkDefault gatus.settings.web.port);
      };
      service = {upstream, ...}: {
        enable = mkIf upstream.servers.local.enable (mkDefault false);
        accessService = {
          name = "gatus";
        };
      };
    };
    virtualHosts = let
      copyFromVhost = mkDefault "gatus";
      locations = {
        "/" = {
          proxy.enable = true;
        };
      };
    in {
      gatus = {
        inherit name locations;
        proxy.upstream = mkDefault upstreamName;
      };
      gatus'local = {
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
