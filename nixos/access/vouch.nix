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
    domain = mkOption {
      type = str;
      default = "login.${networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "login.local.${networking.domain}";
    };
    tailDomain = mkOption {
      type = str;
      default = "login.tail.${networking.domain}";
    };
    useACMEHost = mkOption {
      type = nullOr str;
      default = null;
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
        mkOptionDefault "http://${host}:${toString cfg.port}";
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
          proxyPass = mkDefault (access.url + "/validate");
          recommendedProxySettings = mkDefault false;
          extraConfig =
            if config.local.trusted
            then ''
              if ($http_x_host = ''') {
                set $http_x_host $host;
              }
              proxy_set_header Host $http_x_host;
            ''
            else ''
              proxy_set_header Host $host;
            '';
        };
      };
      localLocations = kanidmDomain: {
        "/".extraConfig = ''
          proxy_redirect $scheme://${nginx.access.kanidm.domain or "id.${networking.domain}"}/ $scheme://${kanidmDomain}/;
        '';
      };
    in {
      ${access.localDomain} = mkIf (access.useACMEHost != null) {
        local.enable = true;
        locations = mkMerge [
          locations
          (localLocations nginx.access.kanidm.localDomain or "id.local.${networking.domain}")
        ];
        useACMEHost = mkDefault access.useACMEHost;
        forceSSL = true;
      };
      ${access.tailDomain} = mkIf tailscale.enable {
        local.enable = true;
        locations = mkMerge [
          locations
          (localLocations nginx.access.kanidm.tailDomain or "id.tail.${networking.domain}")
        ];
        useACMEHost = mkDefault access.useACMEHost;
        addSSL = mkIf (access.useACMEHost != null) (mkDefault true);
      };
    };
  };
}
