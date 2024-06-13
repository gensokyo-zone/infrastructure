{
  config,
  access,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mapDefaults;
  inherit (lib.modules) mkIf mkDefault;
  inherit (lib.lists) optional;
  inherit (config.services) nginx;
  system = access.systemForService "freepbx";
  inherit (system.exports.services) freepbx;
  upstreamName = "freepbx";
  upstreamName'ucp = "freepbx'ucp";
in {
  config.services.nginx = {
    upstreams' = {
      ${upstreamName} = {
        servers.access = {
          accessService = mapDefaults {
            inherit (freepbx) name id;
            system = system.name;
            port = "https";
          };
        };
      };
      ${upstreamName'ucp} = {
        servers.access = {
          accessService = mapDefaults {
            inherit (freepbx) name id;
            system = system.name;
            port = "ucp-ssl";
            getAddressFor = "getAddress4For";
          };
        };
      };
    };
    virtualHosts = let
      ucpPath = "/socket.io/";
      # TODO: ports.asterisk/asterisk-ssl?
      hostCommon = {xvars, ...}: {
        extraConfig = ''
          proxy_buffer_size 128k;
          proxy_buffers 4 256k;
          proxy_busy_buffers_size 256k;
          proxy_cookie_flags ~ nosamesite;
          proxy_cookie_domain ~ ${xvars.get.host};
        '';
        locations = {
          ${ucpPath} = {
            xvars,
            virtualHost,
            ...
          }: {
            proxy = {
              enable = true;
              websocket.enable = true;
              headers.hide.Access-Control-Allow-Origin = true;
            };
            headers.set.Access-Control-Allow-Origin = "${xvars.get.scheme}://${virtualHost.serverName}";
          };
        };
      };
      hostWeb = {...}: {
        imports = [hostCommon];
        locations = {
          "/" = {xvars, ...}: {
            xvars.enable = true;
            proxy = {
              enable = true;
              redirect = {
                enable = true;
                fromScheme = xvars.get.proxy_scheme;
              };
            };
          };
          ${ucpPath}.proxy = {
            upstream = mkDefault nginx.virtualHosts.freepbx'ucp.proxy.upstream;
          };
        };
      };
      name.shortServer = mkDefault "pbx";
    in {
      freepbx = {...}: {
        imports = [hostWeb];
        vouch.enable = mkDefault true;
        ssl.force = true;
        proxy.upstream = upstreamName;
        inherit name;
      };
      freepbx'ucp = {...}: {
        imports = [hostCommon];
        serverName = mkDefault nginx.virtualHosts.freepbx.serverName;
        ssl.cert.copyFromVhost = "freepbx";
        listen' = {
          ucp = {
            port = mkDefault freepbx.ports.ucp.port;
            extraParameters = ["default_server"];
          };
          ucpSsl = {
            port = mkDefault freepbx.ports.ucp-ssl.port;
            ssl = true;
            extraParameters = ["default_server"];
          };
        };
        proxy = {
          upstream = mkDefault upstreamName'ucp;
          websocket.enable = true;
        };
        vouch.enable = mkDefault true;
        local.denyGlobal = mkDefault nginx.virtualHosts.freepbx.local.denyGlobal;
      };
      freepbx'local = {...}: {
        imports = [hostWeb];
        listen' = {
          http = {};
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
        proxy.copyFromVhost = "freepbx";
        local.enable = true;
        inherit name;
      };
    };
  };
  config.networking.firewall = let
    websocketPorts = virtualHost:
      [
        virtualHost.listen'.ucp.port
      ]
      ++ optional virtualHost.listen'.ucpSsl.enable virtualHost.listen'.ucpSsl.port;
  in {
    interfaces.local.allowedTCPPorts = websocketPorts nginx.virtualHosts.freepbx'local;
    allowedTCPPorts = mkIf (!nginx.virtualHosts.freepbx'ucp.local.denyGlobal) (websocketPorts nginx.virtualHosts.freepbx'ucp);
  };
}
