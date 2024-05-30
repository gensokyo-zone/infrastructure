{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) prometheus;
  name.shortServer = mkDefault "prometheus";
  upstreamName = "prometheus'access";
in {
  config.services.nginx = {
    upstreams'.${upstreamName}.servers = {
      local = {
        enable = mkDefault prometheus.enable;
        addr = mkDefault "localhost";
        port = mkIf prometheus.enable (mkDefault prometheus.port);
      };
      service = {upstream, ...}: {
        enable = mkIf upstream.servers.local.enable (mkDefault false);
        accessService = {
          name = "prometheus";
        };
      };
    };
    virtualHosts = let
      copyFromVhost = mkDefault "prometheus";
      vouch.enable = mkDefault true;
      locations = {
        "/" = {
          proxy.enable = true;
        };
      };
    in {
      prometheus = {
        inherit name locations vouch;
        proxy.upstream = mkDefault upstreamName;
      };
      prometheus'local = {
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
