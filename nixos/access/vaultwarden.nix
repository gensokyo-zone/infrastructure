{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.vaultwarden;
  upstreamName = "vaultwarden'access";
  locations = {
    "/".proxy.enable = true;
    "/notifications/hub" = {
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
