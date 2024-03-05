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
      listenPorts = {
        http = { };
        https.ssl = true;
        stream.port = mkDefault access.streamPort;
      };
      name.shortServer = mkDefault "kitchen";
      kTLS = mkDefault true;
    in {
      kitchencam = {
        inherit name locations listenPorts kTLS;
        vouch.enable = true;
      };
      kitchencam'local = {
        inherit name locations listenPorts kTLS;
        local.enable = true;
      };
    };
  };
  config.networking.firewall.allowedTCPPorts = [
    access.streamPort
  ];
}
