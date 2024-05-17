{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (config.services) barcodebuddy nginx;
  name.shortServer = mkDefault "bbuddy";
  serverName = "@bbuddy_internal";
  websocketPath = "/incl/sse/";
  websocketLocation = {
    proxy = {
      enable = true;
      websocket.enable = true;
    };
    extraConfig = ''
      proxy_read_timeout 1d;
    '';
  };
in {
  config.services.nginx = {
    vouch.enable = true;
    proxied.enable = true;
  };
  config.services.nginx.virtualHosts = {
    barcodebuddy'php = mkIf barcodebuddy.enable {
      inherit serverName;
      proxied.enable = mkDefault true;
      local.denyGlobal = true;
    };
    barcodebuddy = {
      inherit name;
      vouch = {
        enable = true;
        requireAuth = false;
      };
      proxy = {
        upstream = mkIf barcodebuddy.enable (
          mkDefault
          "nginx'proxied"
        );
        host = mkDefault serverName;
      };
      locations = {
        "/api/" = {
          proxy.enable = true;
        };
        "/" = {
          proxy.enable = true;
          vouch.requireAuth = true;
        };
        ${websocketPath} = mkMerge [
          websocketLocation
          {
            vouch.requireAuth = true;
          }
        ];
      };
    };
    barcodebuddy'local = {
      inherit name;
      ssl.cert.copyFromVhost = "barcodebuddy";
      local.enable = mkDefault true;
      proxy = {
        upstream = mkDefault nginx.virtualHosts.barcodebuddy.proxy.upstream;
        host = mkDefault nginx.virtualHosts.barcodebuddy.proxy.host;
      };
      locations = {
        "/" = {config, ...}: {
          proxy = {
            enable = true;
            redirect = {
              enable = true;
              fromHost = config.proxy.host;
            };
          };
        };
        ${websocketPath} = websocketLocation;
      };
    };
  };
}
