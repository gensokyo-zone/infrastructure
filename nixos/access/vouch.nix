{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) tailscale nginx;
  cfg = config.services.vouch-proxy;
in {
  config.services.nginx = {
    upstreams'.vouch'access.servers.access = {
      accessService = {
        inherit (nginx.upstreams'.vouch'auth.servers.service.accessService) system name id port;
      };
    };
    upstreams'.vouch'access'local.servers.access = {
      accessService = {
        inherit (nginx.upstreams'.vouch'auth'local.servers.service.accessService) system name id port;
      };
    };
    virtualHosts = let
      locations = {
        "/" = {
          ssl.force = true;
          proxy.enable = true;
          extraConfig = ''
            proxy_redirect default;
          '';
        };
        "/validate" = {config, virtualHost, ...}: {
          proxied.enable = true;
          proxy.enable = true;
          local.denyGlobal = true;
        };
      };
      name.shortServer = mkDefault "login";
    in {
      vouch = { xvars, ... }: {
        inherit name locations;
        serverAliases = [ nginx.vouch.doubleProxy.serverName ];
        proxied.enable = true;
        proxy = {
          upstream = mkDefault "vouch'access";
          host = mkDefault xvars.get.host;
        };
        local.denyGlobal = true;
      };
      vouch'local = { xvars, ... }: {
        name = {
          inherit (name) shortServer;
          includeTailscale = mkDefault false;
        };
        serverAliases = mkIf cfg.enable [ nginx.vouch.doubleProxy.localServerName ];
        proxied.enable = true;
        proxy = {
          upstream = mkDefault "vouch'access'local";
          host = mkDefault xvars.get.host;
        };
        local.enable = true;
        ssl = {
          force = true;
          cert.copyFromVhost = "vouch";
        };
        inherit locations;
      };
      vouch'tail = { xvars, ... }: {
        enable = mkDefault (tailscale.enable && !nginx.virtualHosts.vouch'local.name.includeTailscale);
        ssl.cert.copyFromVhost = "vouch'local";
        name = {
          inherit (name) shortServer;
          qualifier = mkDefault "tail";
        };
        local.enable = true;
        proxy = {
          upstream = mkDefault nginx.virtualHosts.vouch'local.proxy.upstream;
          host = mkDefault xvars.get.host;
        };
        inherit locations;
      };
    };
  };
}
