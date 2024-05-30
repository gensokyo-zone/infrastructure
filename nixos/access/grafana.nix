{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) grafana;
  name.shortServer = mkDefault "mon";
  upstreamName = "grafana'access";
in {
  config.services.nginx = {
    upstreams'.${upstreamName}.servers = {
      local = {
        enable = mkDefault grafana.enable;
        addr = mkDefault "localhost";
        port = mkIf grafana.enable (mkDefault grafana.settings.server.http_port);
      };
      service = {upstream, ...}: {
        enable = mkIf upstream.servers.local.enable (mkDefault false);
        accessService = {
          name = "grafana";
        };
      };
    };
    virtualHosts = let
      copyFromVhost = mkDefault "grafana";
      vouch.enable = mkDefault true;
      locations = {
        "/" = {
          proxy.enable = true;
        };
      };
    in {
      grafana = {
        inherit name locations vouch;
        proxy.upstream = mkDefault upstreamName;
      };
      grafana'local = {
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
