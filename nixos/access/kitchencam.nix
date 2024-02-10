{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services.nginx) virtualHosts;
  access = config.services.nginx.access.kitchencam;
in {
  options.services.nginx.access.kitchencam = with lib.types; {
    host = mkOption {
      type = str;
      default = "kitchencam.local.${config.networking.domain}";
    };
    url = mkOption {
      type = str;
      default = "http://${access.host}:8080";
    };
    streamUrl = mkOption {
      type = str;
      default = "http://${access.host}:8081";
    };
    domain = mkOption {
      type = str;
      default = "kitchen.${config.networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "kitchen.local.${config.networking.domain}";
    };
    tailDomain = mkOption {
      type = str;
      default = "kitchen.tail.${config.networking.domain}";
    };
    useACMEHost = mkOption {
      type = nullOr str;
      default = null;
    };
  };
  config.services.nginx = {
    virtualHosts = let
      extraConfig = ''
        proxy_redirect off;
        proxy_buffering off;
      '';
      locations = {
        "/" = {
          proxy.websocket.enable = true;
          proxyPass = access.url;
        };
        "/stream" = {
          proxy.websocket.enable = true;
          proxyPass = access.streamUrl;
        };
      };
    in {
      ${access.domain} = {
        vouch.enable = true;
        kTLS = mkDefault true;
        inherit (access) useACMEHost;
        forceSSL = mkDefault (access.useACMEHost != null);
        inherit locations extraConfig;
      };
      ${access.localDomain} = {
        serverAliases = mkIf config.services.tailscale.enable [ access.tailDomain ];
        inherit (virtualHosts.${access.domain}) useACMEHost;
        addSSL = mkDefault (access.useACMEHost != null || virtualHosts.${access.domain}.addSSL || virtualHosts.${access.domain}.forceSSL);
        kTLS = mkDefault true;
        local.enable = true;
        inherit locations extraConfig;
      };
    };
  };
}
