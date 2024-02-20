{
  config,
  access,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.lists) optional;
  inherit (config.services) nginx;
  system = access.systemForService "freepbx";
  inherit (system.exports.services) freepbx;
in {
  config.services.nginx = {
    virtualHosts = let
      proxyScheme = "https";
      url = access.proxyUrlFor { serviceName = "freepbx"; portName = proxyScheme; };
      ucpUrl = access.proxyUrlFor { serviceName = "freepbx"; portName = "ucp-ssl"; };
      # TODO: ports.asterisk/asterisk-ssl?
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
          proxyPass = mkDefault url;
        };
        "/socket.io" = {
          proxy.websocket.enable = true;
          proxyPass = mkDefault "${ucpUrl}/socket.io";
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
            port = mkDefault freepbx.ports.ucp.port;
            extraParameters = [ "default_server" ];
          };
          ucpSsl = {
            port = mkDefault freepbx.ports.ucp-ssl.port;
            ssl = true;
            extraParameters = [ "default_server" ];
          };
        };
        proxy.websocket.enable = true;
        vouch.enable = mkDefault true;
        local.denyGlobal = mkDefault nginx.virtualHosts.freepbx.local.denyGlobal;
        locations."/socket.io" = {
          inherit (locations."/socket.io") proxy extraConfig;
          proxyPass = mkDefault nginx.virtualHosts.freepbx.locations."/socket.io".proxyPass;
        };
        inherit extraConfig kTLS;
      };
      freepbx'local = {
        listen' = {
          http = { };
          https.ssl = true;
          ucp = {
            port = mkDefault nginx.virtualHosts.freepbx'ucp.listen'.ucp.port;
          };
          ucpSsl = {
            port = mkDefault nginx.virtualHosts.freepbx'ucp.listen'.ucpSsl.port;
            ssl = true;
          };
        };
        ssl.cert.copyFromVhost = "freepbx";
        local.enable = true;
        locations = {
          "/" = {
            proxyPass = mkDefault nginx.virtualHosts.freepbx.locations."/".proxyPass;
          };
          "/socket.io" = {
            inherit (locations."/socket.io") proxy extraConfig;
            proxyPass = mkDefault nginx.virtualHosts.freepbx.locations."/socket.io".proxyPass;
          };
        };
        inherit name extraConfig kTLS;
      };
    };
  };
  config.networking.firewall = let
    websocketPorts = virtualHost: [
      virtualHost.listen'.ucp.port
    ] ++ optional virtualHost.listen'.ucpSsl.enable virtualHost.listen'.ucpSsl.port;
  in {
    interfaces.local.allowedTCPPorts = websocketPorts nginx.virtualHosts.freepbx'local;
    allowedTCPPorts = mkIf (!nginx.virtualHosts.freepbx'ucp.local.denyGlobal) (websocketPorts nginx.virtualHosts.freepbx'ucp);
  };
}
