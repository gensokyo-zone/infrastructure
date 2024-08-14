{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkAfter mkDefault;
  name.shortServer = mkDefault "print";
  upstreamName = "moonraker'access";
  upstreamNameMotion = "moonraker'motion";
  inherit (config.services) fluidd;
  cfg = config.services.moonraker;
in {
  config.services.nginx = {
    upstreams'.${upstreamName} = {
      servers = {
        local = {
          enable = mkDefault cfg.enable;
          addr = mkDefault "localhost";
          port = mkIf cfg.enable (mkDefault cfg.port);
        };
        service = {upstream, ...}: {
          enable = mkIf upstream.servers.local.enable (mkDefault false);
          accessService = {
            name = "moonraker";
          };
        };
      };
    };
    upstreams'.${upstreamNameMotion} = {
      servers.service = {
        accessService = {
          name = "motion";
          port = "stream";
        };
      };
    };
    virtualHosts = let
      copyFromVhost = mkDefault "moonraker";
      root = "${fluidd.package}/share/fluidd/htdocs";
      locations = {
        "/" = {
          inherit root;
          index = "index.html";
          tryFiles = "$uri $uri/ @moonraker";
          # XXX: gzip filter failed to use preallocated memory: 350272 of 336176
          extraConfig = ''
            gzip off;
          '';
        };
        "/index.html" = {
          inherit root;
          headers.set.Cache-Control = "no-store, no-cache, must-revalidate";
        };
        "/webcam" = {
          proxy = {
            enable = true;
            upstream = upstreamNameMotion;
            path = "/2/stream";
          };
          extraConfig = ''
            proxy_buffering off;
            set $args "";
          '';
        };
        "/websocket" = {
          proxy = {
            enable = true;
            websocket.enable = true;
          };
        };
        # TODO: "~ ^/(printer|api|access|machine|server)/" ?
        "@moonraker" = {
          proxy = {
            enable = true;
            path = mkDefault "";
            # TODO: path = mkDefault "$request_uri";
          };
        };
      };
    in {
      moonraker = {
        inherit name;
        locations = mkMerge [
          locations
          {
            "/index.html".vouch.requireAuth = true;
            "/webcam".vouch.requireAuth = true;
            "/websocket".vouch.requireAuth = true;
            "@moonraker".vouch.requireAuth = true;
          }
        ];
        proxy.upstream = mkDefault upstreamName;
        vouch = {
          enable = mkDefault true;
          requireAuth = false;
        };
      };
      moonraker'local = {
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
