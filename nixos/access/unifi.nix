{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault;
  cfg = config.services.unifi;
  upstreamName = "unifi'access";
in {
  config.services.nginx = {
    vouch.enable = true;
    upstreams'.${upstreamName}.servers = {
      local = {
        enable = mkDefault cfg.enable;
        addr = mkDefault "localhost";
        port = mkDefault 8443;
        ssl.enable = mkDefault true;
      };
      access = {upstream, ...}: {
        enable = mkDefault (!upstream.servers.local.enable);
        accessService = {
          name = "unifi";
          port = "management";
        };
      };
    };
    virtualHosts = let
      extraConfig = ''
        proxy_redirect off;
        proxy_buffering off;
      '';
      locations = {
        "/" = {
          proxy.enable = true;
        };
        "/wss/" = {
          proxy = {
            enable = true;
            websocket.enable = true;
          };
        };
      };
      name.shortServer = mkDefault "unifi";
      copyFromVhost = mkDefault "unifi";
    in {
      unifi = {
        inherit name extraConfig locations;
        vouch.enable = mkDefault true;
        ssl.force = mkDefault true;
        proxy.upstream = mkDefault upstreamName;
      };
      unifi'local = {
        inherit name extraConfig locations;
        ssl.cert = {
          inherit copyFromVhost;
        };
        local.enable = true;
        proxy = {
          inherit copyFromVhost;
        };
      };
    };
  };
}
