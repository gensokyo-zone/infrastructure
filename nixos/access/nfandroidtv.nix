{
  config,
  system,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) nginx;
  inherit (system.exports.services) nfandroidtv;
  upstreamName = "nfandroidtv'bedroom";
in {
  config.services.nginx = {
    vouch.enable = true;
    upstreams'.${upstreamName}.servers = {
      android = {
        settings.fail_timeout = mkDefault "5s";
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
        };
      };
      name.shortServer = mkDefault nfandroidtv.id;
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
          extraConfig = ''
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
