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
          extraConfig = ''
            proxy_redirect default;
            set $x_proxy_host $x_forwarded_host;
          '';
        };
        "/validate" = {config, virtualHost, ...}: {
          proxied.enable = true;
          proxyPass = mkDefault (virtualHost.locations."/".proxyPass + "/validate");
          proxy.headers.enableRecommended = true;
          local.denyGlobal = true;
          extraConfig = ''
            set $x_proxy_host $x_forwarded_host;
          '';
        };
      };
      localLocations = kanidmDomain: mkIf (nginx.vouch.localSso.enable && false) {
        "/" = {
          proxied.xvars.enable = true;
          extraConfig = ''
            proxy_redirect https://sso.${networking.domain}/ $x_scheme://${kanidmDomain}/;
          '';
        };
      };
      name.shortServer = mkDefault "login";
    in {
      vouch = {
        inherit name;
        serverAliases = [ nginx.vouch.doubleProxy.serverName ];
        proxied.enable = true;
        local.denyGlobal = true;
        locations = mkMerge [
          locations
          {
            "/".proxyPass = mkDefault (
              access.proxyUrlFor { serviceName = "vouch-proxy"; serviceId = "login"; }
            );
          }
        ];
      };
      vouch'local = {
        name = {
          inherit (name) shortServer;
          includeTailscale = mkDefault false;
        };
        serverAliases = mkIf cfg.enable [ nginx.vouch.doubleProxy.localServerName ];
        proxied.enable = true;
        local.enable = true;
        ssl = {
          force = true;
          cert.copyFromVhost = "vouch";
        };
        locations = mkMerge [
          locations
          {
            "/".proxyPass = mkDefault (
              access.proxyUrlFor { serviceName = "vouch-proxy"; serviceId = "login.local"; }
            );
          }
          (localLocations "sso.local.${networking.domain}")
        ];
      };
      vouch'tail = {
        enable = mkDefault (tailscale.enable && !nginx.virtualHosts.vouch'local.name.includeTailscale);
        ssl.cert.copyFromVhost = "vouch'local";
        name = {
          inherit (name) shortServer;
          qualifier = mkDefault "tail";
        };
        local.enable = true;
        locations = mkMerge [
          locations
          {
            "/".proxyPass = mkDefault nginx.virtualHosts.vouch'local.locations."/".proxyPass;
          }
          (localLocations "sso.tail.${networking.domain}")
        ];
      };
    };
  };
}
