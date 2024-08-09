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
  serverName = "print.local.${domain}";
  # TODO: serverName = "@fluidd_internal";
in {
  config.services.nginx = {
    upstreams'.${upstreamName} = {
      host = serverName;
      servers.service = {
        accessService = {
          name = "nginx";
          system = "logistics";
          port = "proxied";
          # XXX: logistics doesn't listen on v6
          getAddressFor = "getAddress4For";
        };
      };
    };
    virtualHosts = let
      copyFromVhost = mkDefault "fluidd";
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
