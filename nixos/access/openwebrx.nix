{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) openwebrx;
  name.shortServer = mkDefault "webrx";
  upstreamName = "openwebrx'access";
in {
  config.services.nginx = {
    upstreams'.${upstreamName}.servers = {
      local = {
        enable = mkDefault openwebrx.enable;
        addr = mkDefault "localhost";
        port = mkIf openwebrx.enable (mkDefault openwebrx.port);
      };
      service = {upstream, ...}: {
        enable = mkIf upstream.servers.local.enable (mkDefault false);
        accessService = {
          name = "openwebrx";
        };
      };
    };
    virtualHosts = let
      copyFromVhost = mkDefault "openwebrx";
      locations = {
        "/" = {
          proxy.enable = true;
        };
        "/ws/" = {
          proxy = {
            enable = true;
            websocket.enable = true;
          };
          extraConfig = ''
            proxy_buffering off;
          '';
        };
      };
    in {
      openwebrx = {
        inherit name locations;
        proxy.upstream = mkDefault upstreamName;
        vouch.enable = mkDefault true;
      };
      openwebrx'local = {
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
