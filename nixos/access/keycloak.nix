{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.keycloak;
  upstreamName = "keycloak'access";
  locations."/".proxy.enable = true;
  name.shortServer = mkDefault "sso";
  copyFromVhost = mkDefault "keycloak";
in {
  config.services.nginx = {
    upstreams'.${upstreamName}.servers = {
      local = mkIf cfg.enable {
        enable = mkDefault true;
        addr = mkDefault "localhost";
        port = mkDefault cfg.port;
        ssl.enable = mkIf (cfg.protocol == "https") true;
      };
      access = { upstream, ... }: {
        enable = mkDefault (!upstream.servers.local.enable or false);
        accessService = {
          name = "keycloak";
          port = "https";
        };
      };
    };
    virtualHosts = {
      keycloak = {
        inherit name locations;
        ssl.force = mkDefault true;
        proxy.upstream = mkDefault upstreamName;
      };
      keycloak'local = {
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
