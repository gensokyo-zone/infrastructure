{
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) domain;
  inherit (lib.modules) mkDefault;
  name.shortServer = mkDefault "print";
  upstreamName = "fluidd'access";
  serverName = "@fluidd_internal"; # "print.local.${domain}"
in {
  config.services.nginx = {
    upstreams'.${upstreamName} = {
      host = serverName;
      servers.service = {
        accessService = {
          name = "nginx";
          system = "logistics";
          port = "proxied";
        };
      };
    };
    virtualHosts = let
      copyFromVhost = mkDefault "fluidd";
      # TODO: just use moonraker as the upstream directly?
      locations = {
        "/" = {
          proxy = {
            enable = true;
            websocket.enable = true;
          };
        };
      };
    in {
      fluidd = {
        inherit name locations;
        proxy.upstream = mkDefault upstreamName;
        vouch.enable = mkDefault true;
      };
      fluidd'local = {
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
