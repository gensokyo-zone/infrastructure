{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.lists) head optional;
  inherit (lib.strings) splitString;
  inherit (config.services) nginx;
  access = nginx.access.freepbx;
  hasSsl = nginx.virtualHosts.freepbx'ucp.listen'.ucpSsl.enable;
in {
  options.services.nginx.access.freepbx = with lib.types; {
    host = mkOption {
      type = str;
      default = config.lib.access.getHostnameFor "freepbx" "lan";
    };
    url = mkOption {
      type = str;
      default = "https://${access.host}";
    };
    asteriskPort = mkOption {
      type = port;
      default = 8088;
    };
    asteriskSslPort = mkOption {
      type = port;
      default = 8089;
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
      name.shortServer = mkDefault "pbx";
      kTLS = mkDefault true;
    in {
      freepbx = {
        vouch.enable = mkDefault true;
        ssl.force = true;
        inherit name locations extraConfig kTLS;
      };
      freepbx'ucp = {
        serverName = mkDefault nginx.virtualHosts.freepbx.serverName;
        ssl.cert.copyFromVhost = "freepbx";
        listen' = {
          ucp = {
            port = access.ucpPort;
            extraParameters = [ "default_server" ];
          };
          ucpSsl = {
            port = access.ucpSslPort;
            ssl = true;
            extraParameters = [ "default_server" ];
          };
        };
        proxy.websocket.enable = true;
        vouch.enable = mkDefault true;
        local.denyGlobal = mkDefault nginx.virtualHosts.freepbx.local.denyGlobal;
        locations = {
          inherit (locations) "/socket.io";
        };
        inherit extraConfig kTLS;
      };
      freepbx'local = {
        listen' = {
          http = { };
          https.ssl = true;
          ucp = {
            port = access.ucpPort;
          };
          ucpSsl = {
            port = access.ucpSslPort;
            ssl = true;
          };
        };
        ssl.cert.copyFromVhost = "freepbx";
        local.enable = true;
        inherit name locations extraConfig kTLS;
      };
    };
  };
  config.networking.firewall = let
    websocketPorts = [access.ucpPort] ++ optional hasSsl access.ucpSslPort;
  in {
    interfaces.local.allowedTCPPorts = websocketPorts;
    allowedTCPPorts = mkIf (!nginx.virtualHosts.freepbx'ucp.local.denyGlobal) websocketPorts;
  };
}
