{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.lists) concatMap;
  inherit (config.services) nginx;
  inherit (config.services.nginx) virtualHosts;
  access = config.services.nginx.access.kitchencam;
in {
  options.services.nginx.access.kitchencam = with lib.types; {
    streamPort = mkOption {
      type = port;
      default = 8081;
    };
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
      default = "http://${access.host}:${toString access.streamPort}";
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
      addSSL = access.useACMEHost != null || virtualHosts.${access.domain}.addSSL || virtualHosts.${access.domain}.forceSSL;
      extraConfig = ''
        proxy_redirect off;
        proxy_buffering off;
      '';
      locations = {
        "/" = {
          proxyPass = access.url;
        };
        "~ ^/[0-9]+/(stream|motion|substream|current|source|status\\.json)$" = {
          proxyPass = access.streamUrl;
          inherit extraConfig;
        };
        "~ ^/(stream|motion|substream|current|source|cameras\\.json|status\\.json)$" = {
          proxyPass = access.streamUrl;
          inherit extraConfig;
        };
      };
      streamListen = { config, ... }: {
        listen = concatMap (addr: [
          (mkIf config.addSSL {
            inherit addr;
            port = nginx.defaultSSLListenPort;
            ssl = true;
          })
          {
            inherit addr;
            port = nginx.defaultHTTPListenPort;
          }
          {
            inherit addr;
            port = access.streamPort;
          }
        ]) nginx.defaultListenAddresses;
      };
    in {
      ${access.domain} = mkMerge [ {
        vouch.enable = true;
        kTLS = mkDefault true;
        inherit (access) useACMEHost;
        addSSL = mkDefault (access.useACMEHost != null);
        inherit locations;
      } streamListen ];
      ${access.localDomain} = mkMerge [ {
        serverAliases = mkIf config.services.tailscale.enable [ access.tailDomain ];
        inherit (virtualHosts.${access.domain}) useACMEHost;
        addSSL = mkDefault addSSL;
        kTLS = mkDefault true;
        local.enable = true;
        inherit locations;
      } streamListen ];
    };
  };
  config.networking.firewall.allowedTCPPorts = [
    access.streamPort
  ];
}
