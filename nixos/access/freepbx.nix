{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.lists) head optional concatMap;
  inherit (lib.strings) splitString;
  inherit (config.services) nginx tailscale;
  access = nginx.access.freepbx;
  freepbx = config.lib.access.systemFor "freepbx";
in {
  options.services.nginx.access.freepbx = with lib.types; {
    global.enable =
      mkEnableOption "global access"
      // {
        default = access.useACMEHost != null;
      };
    host = mkOption {
      type = str;
      default = freepbx.access.hostnameForNetwork.local;
    };
    url = mkOption {
      type = str;
      default = "https://${access.host}";
    };
    asteriskPort = mkOption {
      type = port;
      default = 8088;
    };
    ucpPort = mkOption {
      type = port;
      default = 8001;
    };
    ucpSslPort = mkOption {
      type = port;
      default = 8003;
    };
    ucpUrl = mkOption {
      type = str;
      default = "https://${access.host}:${toString access.ucpSslPort}";
    };
    domain = mkOption {
      type = str;
      default = "pbx.${config.networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "pbx.local.${config.networking.domain}";
    };
    tailDomain = mkOption {
      type = str;
      default = "pbx.tail.${config.networking.domain}";
    };
    useACMEHost = mkOption {
      type = nullOr str;
      default = null;
    };
  };
  config.services.nginx = {
    virtualHosts = let
      proxyScheme = head (splitString ":" access.url);
      extraConfig = ''
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;

        set $pbx_scheme $scheme;
        if ($http_x_forwarded_proto) {
          set $pbx_scheme $http_x_forwarded_proto;
        }
        proxy_redirect ${proxyScheme}://$host/ $pbx_scheme://$host/;
      '';
      locations = {
        "/" = {
          proxyPass = access.url;
        };
        "/socket.io" = {
          proxy.websocket.enable = true;
          proxyPass = "${access.ucpUrl}/socket.io";
          extraConfig = ''
            proxy_hide_header Access-Control-Allow-Origin;
            add_header Access-Control-Allow-Origin $pbx_scheme://$host;
          '';
        };
      };
    in {
      ${access.domain} = {
        vouch.enable = mkDefault true;
        local.enable = mkDefault (!access.global.enable);
        addSSL = mkDefault (access.useACMEHost != null);
        kTLS = mkDefault true;
        useACMEHost = mkDefault access.useACMEHost;
        inherit locations extraConfig;
      };
      "${access.domain}@ucp" = {
        serverName = access.domain;
        listen =
          concatMap (addr: [
            {
              inherit addr;
              port = access.ucpPort;
            }
            (mkIf (access.useACMEHost != null) {
              inherit addr;
              port = access.ucpSslPort;
              ssl = true;
            })
          ])
          nginx.defaultListenAddresses;
        proxy.websocket.enable = true;
        local.enable = mkDefault (!access.global.enable);
        addSSL = mkDefault (access.useACMEHost != null);
        kTLS = mkDefault true;
        useACMEHost = mkDefault access.useACMEHost;
        locations = {
          inherit (locations) "/socket.io";
        };
        inherit extraConfig;
      };
      ${access.localDomain} = {
        listen =
          concatMap (addr: [
            {
              inherit addr;
              port = nginx.defaultHTTPListenPort;
            }
            {
              inherit addr;
              port = access.ucpPort;
            }
            (mkIf (access.useACMEHost != null) {
              inherit addr;
              port = nginx.defaultSSLListenPort;
              ssl = true;
            })
            (mkIf (access.useACMEHost != null) {
              inherit addr;
              port = access.ucpSslPort;
              ssl = true;
            })
          ])
          nginx.defaultListenAddresses;
        serverAliases = mkIf tailscale.enable [access.tailDomain];
        useACMEHost = mkDefault access.useACMEHost;
        addSSL = mkDefault (access.useACMEHost != null);
        kTLS = mkDefault true;
        local.enable = true;
        inherit locations extraConfig;
      };
    };
  };
  config.networking.firewall = let
    websocketPorts = [access.ucpPort] ++ optional (access.useACMEHost != null) access.ucpSslPort;
  in {
    interfaces.local.allowedTCPPorts = websocketPorts;
    allowedTCPPorts = mkIf access.global.enable websocketPorts;
  };
}
