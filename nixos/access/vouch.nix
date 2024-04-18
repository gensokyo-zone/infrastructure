{
  config,
  lib,
  access,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (config) networking;
  inherit (config.services) tailscale nginx;
  cfg = config.services.vouch-proxy;
in {
  config.services.nginx = {
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
      localLocations = kanidmDomain: mkIf (nginx.vouch.localSso.enable && false) {
        "/" = { xvars, ... }: {
          extraConfig = ''
            proxy_redirect https://sso.${networking.domain}/ ${xvars.get.scheme}://${kanidmDomain}/;
          '';
        };
      };
      name.shortServer = mkDefault "login";
    in {
      vouch = { xvars, ... }: {
        inherit name locations;
        serverAliases = [ nginx.vouch.doubleProxy.serverName ];
        proxied.enable = true;
        proxy = {
          url = mkDefault (
            access.proxyUrlFor { serviceName = "vouch-proxy"; serviceId = "login"; }
          );
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
          url = mkDefault (
            access.proxyUrlFor { serviceName = "vouch-proxy"; serviceId = "login.local"; }
          );
          host = mkDefault xvars.get.host;
        };
        local.enable = true;
        ssl = {
          force = true;
          cert.copyFromVhost = "vouch";
        };
        locations = mkMerge [
          locations
          (localLocations "sso.local.${networking.domain}")
        ];
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
          url = mkDefault nginx.virtualHosts.vouch'local.locations."/".proxyPass;
          host = mkDefault xvars.get.host;
        };
        locations = mkMerge [
          locations
          (localLocations "sso.tail.${networking.domain}")
        ];
      };
    };
  };
}
