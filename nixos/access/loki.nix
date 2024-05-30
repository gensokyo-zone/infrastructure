{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) loki;
  name.shortServer = mkDefault "logs";
  upstreamName = "loki'access";
in {
  config.services.nginx = {
    # TODO: gRPC port?
    upstreams'.${upstreamName}.servers = {
      local = {
        enable = mkDefault loki.enable;
        addr = mkDefault "localhost";
        port = mkIf loki.enable (mkDefault loki.configuration.server.http_listen_port);
      };
      service = {upstream, ...}: {
        enable = mkIf upstream.servers.local.enable (mkDefault false);
        accessService = {
          name = "loki";
        };
      };
    };
    virtualHosts = let
      copyFromVhost = mkDefault "loki";
      vouch.enable = mkDefault true;
      locations = {
        "/" = {
          proxy.enable = true;
        };
      };
    in {
      loki = {
        inherit name locations vouch;
        proxy.upstream = mkDefault upstreamName;
      };
      loki'local = {
        inherit name locations vouch;
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
