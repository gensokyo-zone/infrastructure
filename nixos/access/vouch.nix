{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (config) networking;
  inherit (config.services) tailscale nginx;
  cfg = config.services.vouch-proxy;
  access = nginx.access.vouch;
in {
  options.services.nginx.access.vouch = with lib.types; {
    url = mkOption {
      type = str;
    };
  };
  config.services.nginx = {
    access.vouch = mkIf cfg.enable {
      url = let
        inherit (cfg.settings.vouch) listen;
        host =
          if listen == "0.0.0.0" || listen == "[::]"
          then "localhost"
          else listen;
      in
        mkOptionDefault "http://${host}:${toString cfg.settings.vouch.port}";
    };
    virtualHosts = let
      locations = {
        "/" = {
          proxyPass = mkDefault access.url;
          extraConfig = ''
            proxy_redirect default;
          '';
        };
        "/validate" = {config, ...}: {
          proxied.enable = true;
          proxyPass = mkDefault (access.url + "/validate");
          proxy.headers.enableRecommended = true;
          local.denyGlobal = true;
          extraConfig = ''
            set $x_proxy_host $x_forwarded_host;
          '';
        };
      };
      localLocations = kanidmDomain: mkIf nginx.vouch.localSso.enable {
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
        inherit name locations;
        ssl.force = true;
      };
      vouch'local = {
        name = {
          inherit (name) shortServer;
          qualifier = mkDefault "local";
          includeTailscale = false;
        };
        local.enable = true;
        ssl.force = true;
        locations = mkMerge [
          locations
          (localLocations "sso.local.${networking.domain}")
        ];
      };
      vouch'tail = {
        enable = mkDefault tailscale.enable;
        name = {
          inherit (name) shortServer;
          qualifier = mkDefault "tail";
        };
        local.enable = true;
        locations = mkMerge [
          locations
          (localLocations "sso.tail.${networking.domain}")
        ];
      };
    };
  };
}
