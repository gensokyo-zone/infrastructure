{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.vaultwarden;
  upstreamName = "vaultwarden'access";
  upstreamName'websocket = "vaultwarden'websocket'access";
  locations = {
    "/".proxy.enable = true;
    "/notifications/hub" = {
      proxy = {
        enable = true;
        upstream = mkDefault upstreamName'websocket;
        websocket.enable = true;
      };
    };
    "/notifications/hub/negotiate" = {
      proxy = {
        enable = true;
        websocket.enable = true;
      };
    };
  };
  name.shortServer = mkDefault "bw";
  copyFromVhost = mkDefault "vaultwarden";
in {
  config.services.nginx = {
    upstreams' = {
      ${upstreamName}.servers = {
        local = mkIf cfg.enable {
          enable = mkDefault true;
          addr = mkDefault "localhost";
          port = mkDefault cfg.port;
        };
        access = {upstream, ...}: {
          enable = mkDefault (!upstream.servers.local.enable or false);
          accessService = {
            name = "vaultwarden";
          };
        };
      };
      ${upstreamName'websocket}.servers = {
        local = mkIf cfg.enable {
          enable = mkDefault (cfg.websocketPort != null);
          addr = mkDefault "localhost";
          port = mkIf (cfg.websocketPort != null) (mkDefault cfg.websocketPort);
        };
        access = {upstream, ...}: {
          enable = mkDefault (!cfg.enable && !upstream.servers.local.enable or false);
          accessService = {
            name = "vaultwarden";
            port = "websocket";
          };
        };
      };
    };
    virtualHosts = {
      vaultwarden = {
        inherit name locations;
        ssl.force = mkDefault true;
        proxy.upstream = mkDefault upstreamName;
      };
      vaultwarden'local = {
        inherit name locations;
        ssl = {
          force = mkDefault true;
          cert = {
            inherit copyFromVhost;
          };
        };
        local.enable = true;
        proxy = {
          inherit copyFromVhost;
        };
      };
    };
  };
}
