{
  config,
  systemConfig,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkAfter mkDefault;
  inherit (config.services) nginx;
  inherit (systemConfig.exports.services) nfandroidtv;
  upstreamName = "nfandroidtv'bedroom";
  name.shortServer = mkDefault nfandroidtv.id;
  timeout = "5s";
in {
  config.services.nginx = {
    vouch.enable = true;
    upstreams'.${upstreamName}.servers = {
      android = {
        settings.fail_timeout = mkDefault timeout;
        addr = mkDefault "10.1.1.67";
        port = mkDefault nfandroidtv.ports.default.port;
        /*accessService = {
          system = "bedroomtv";
          name = "nfandroidtv";
        };*/
      };
      fallback = let
        virtualHost = nginx.virtualHosts.nfandroidtv'fallback;
        listen = virtualHost.listen'.nfandroidtv;
      in {
        addr = mkDefault listen.addr;
        port = mkDefault listen.port;
        settings.backup = mkDefault true;
      };
    };
    virtualHosts = let
      locations = {
        "/" = {
          proxy.enable = true;
          extraConfig = ''
            proxy_connect_timeout ${timeout};
          '';
        };
      };
      listen'.nfandroidtv = {
        port = nfandroidtv.ports.default.port;
        extraParameters = ["default_server"];
      };
    in {
      nfandroidtv'local = {
        inherit name locations listen';
        local.enable = true;
        proxy.upstream = mkDefault upstreamName;
      };
      nfandroidtv'fallback = {
        serverName = "@nfandroidtv_fallback";
        locations."/" = {
          extraConfig = mkAfter ''
            add_header Content-Type 'text/html';
            return 200 'OK';
          '';
        };
        listen'.nfandroidtv = {
          addr = "127.0.0.1";
          port = 7677;
          extraParameters = ["default_server"];
        };
      };
    };
  };
  config.networking.firewall.interfaces.lan = let
    virtualHost = nginx.virtualHosts.nfandroidtv'local;
    listen = virtualHost.listen'.nfandroidtv;
  in mkIf (virtualHost.enable && listen.enable) {
    allowedTCPPorts = [ listen.port ];
  };
}
