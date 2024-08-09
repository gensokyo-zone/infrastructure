{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) octoprint;
  name.shortServer = mkDefault "print";
  upstreamName = "octoprint'access";
in {
  config.services.nginx = {
    upstreams'.${upstreamName}.servers = {
      local = {
        enable = mkDefault octoprint.enable;
        addr = mkDefault "localhost";
        port = mkIf octoprint.enable (mkDefault octoprint.port);
      };
      service = {upstream, ...}: {
        enable = mkIf upstream.servers.local.enable (mkDefault false);
        accessService = {
          name = "octoprint";
          # XXX: logistics doesn't listen on v6
          getAddressFor = "getAddress4For";
        };
      };
    };
    virtualHosts = let
      copyFromVhost = mkDefault "octoprint";
      locations = {
        "/" = {
          proxy.enable = true;
        };
        "/sockjs/" = {
          proxy = {
            enable = true;
            websocket.enable = true;
          };
        };
        # TODO: unprotect timelapse download links via vouch? may also need guest permissions...
        # TODO: make a view alternate location prefix that changes content-type?
      };
    in {
      octoprint = {
        inherit name locations;
        proxy.upstream = mkDefault upstreamName;
        vouch.enable = mkDefault true;
      };
      octoprint'local = {
        inherit name locations;
        ssl.cert = {
          inherit copyFromVhost;
        };
        proxy = {
          inherit copyFromVhost;
        };
        local.enable = mkDefault true;
      };
    };
  };
}
