{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) nginx home-assistant;
  name.shortServer = mkDefault "home";
  listen' = {
    http = { };
    https.ssl = true;
    hass = {
      enable = !home-assistant.enable;
      port = mkDefault home-assistant.config.http.server_port;
      extraParameters = [ "default_server" ];
    };
  };
  upstreamName = "home-assistant'access";
in {
  config.services.nginx = {
    upstreams'.${upstreamName}.servers = {
      local = {
        enable = mkDefault home-assistant.enable;
        addr = mkDefault "localhost";
        port = mkIf home-assistant.enable (mkDefault home-assistant.config.http.server_port);
      };
      service = { upstream, ... }: {
        enable = mkIf upstream.servers.local.enable (mkDefault false);
        accessService = {
          name = "home-assistant";
        };
      };
    };
    virtualHosts = let
      copyFromVhost = mkDefault "home-assistant";
      locations = {
        "/" = {
          proxy.enable = true;
        };
        "/api/websocket" = {
          proxy = {
            enable = true;
            websocket.enable = true;
          };
        };
      };
    in {
      home-assistant = {
        inherit name locations;
        proxy.upstream = mkDefault upstreamName;
      };
      home-assistant'local = {
        inherit name listen' locations;
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
  config.networking.firewall.allowedTCPPorts = let
    inherit (nginx.virtualHosts.home-assistant'local) listen';
  in mkIf nginx.virtualHosts.home-assistant'local.enable [
    (mkIf listen'.hass.enable listen'.hass.port)
  ];
}
