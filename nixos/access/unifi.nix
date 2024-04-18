{
  config,
  lib,
  access,
  ...
}: let
  inherit (lib.modules) mkDefault;
  inherit (config.services) nginx;
  cfg = config.services.unifi;
in {
  config.services.nginx = {
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
      kTLS = mkDefault true;
    in {
      unifi = {
        inherit name extraConfig kTLS locations;
        vouch.enable = mkDefault true;
        ssl.force = mkDefault true;
        proxy.url = mkDefault (if cfg.enable
          then "https://localhost:8443"
          else access.proxyUrlFor { serviceName = "unifi"; portName = "management"; }
        );
      };
      unifi'local = {
        inherit name extraConfig kTLS locations;
        ssl.cert.copyFromVhost = "unifi";
        local.enable = true;
        proxy.url = mkDefault nginx.virtualHosts.unifi.proxy.url;
      };
    };
  };
}
