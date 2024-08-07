{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) nginx fluidd;
  name.shortServer = mkDefault "print";
  upstreamName = "fluidd'access";
in {
  config.services.nginx = {
    upstreams'.${upstreamName}.servers = {
      service = {upstream, ...}: {
        enable = true;
        accessService = {
          name = "nginx";
          system = "logistics";
          port = "http";
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
        proxy = {
          upstream = mkDefault upstreamName;
          host = nginx.virtualHosts.fluidd'local.serverName;
        };
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
