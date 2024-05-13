{
  config,
  access,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.lists) optional;
  inherit (config.services) nginx;
  system = access.systemForService "freepbx";
  inherit (system.exports.services) freepbx;
in {
  config.services.nginx = {
    virtualHosts = let
      proxyScheme = "https";
      url = access.proxyUrlFor { serviceName = "freepbx"; portName = proxyScheme; };
      ucpUrl = access.proxyUrlFor { serviceName = "freepbx"; portName = "ucp-ssl"; getAddressFor = "getAddress4For"; };
      ucpPath = "/socket.io";
      # TODO: ports.asterisk/asterisk-ssl?
      extraConfig = ''
        proxy_buffer_size 128k;
        proxy_buffers 4 256k;
        proxy_busy_buffers_size 256k;
      '';
      locations = {
        "/" = { xvars, ... }: {
          xvars.enable = true;
          proxy = {
            enable = true;
            redirect = {
              enable = true;
              fromScheme = xvars.get.proxy_scheme;
            };
          };
        };
        ${ucpPath} = { xvars, virtualHost, ... }: {
          proxy = {
            enable = true;
            websocket.enable = true;
            headers.hide.Access-Control-Allow-Origin = true;
          };
          headers.set.Access-Control-Allow-Origin = "${xvars.get.scheme}://${virtualHost.serverName}";
        };
      };
      allLocations = mkMerge [
        locations
        {
          ${ucpPath}.proxy.url = mkDefault nginx.virtualHosts.freepbx'ucp.proxy.url;
        }
      ];
      name.shortServer = mkDefault "pbx";
    in {
      freepbx = {
        vouch.enable = mkDefault true;
        ssl.force = true;
        proxy.url = mkDefault url;
        locations = allLocations;
        inherit name extraConfig;
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
        proxy = {
          url = mkDefault ucpUrl;
          websocket.enable = true;
        };
        vouch.enable = mkDefault true;
        local.denyGlobal = mkDefault nginx.virtualHosts.freepbx.local.denyGlobal;
        locations = {
          inherit (locations) "/socket.io";
        };
        inherit extraConfig;
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
        proxy.url = mkDefault nginx.virtualHosts.freepbx.proxy.url;
        local.enable = true;
        locations = allLocations;
        inherit name extraConfig;
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
