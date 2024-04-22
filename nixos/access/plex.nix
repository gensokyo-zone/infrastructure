{
  config,
  lib,
  access,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) nginx;
  cfg = config.services.plex;
  upstreamName = "plex'access";
in {
  config.services.nginx = {
    upstreams'.${upstreamName}.servers = {
      local = {
        enable = mkDefault cfg.enable;
        addr = mkDefault "localhost";
        port = mkDefault cfg.port;
      };
      access = { upstream, ... }: {
        enable = mkDefault (!upstream.servers.local.enable);
        accessService.name = "plex";
      };
    };
    virtualHosts = let
      extraConfig = ''
        # Some players don't reopen a socket and playback stops totally instead of resuming after an extended pause
        send_timeout 100m;
        # Buffering off send to the client as soon as the data is received from Plex.
        proxy_redirect off;
        proxy_buffering off;
      '';
      headers.set = {
        X-Plex-Client-Identifier = "$http_x_plex_client_identifier";
        X-Plex-Device = "$http_x_plex_device";
        X-Plex-Device-Name = "$http_x_plex_device_name";
        X-Plex-Platform = "$http_x_plex_platform";
        X-Plex-Platform-Version = "$http_x_plex_platform_version";
        X-Plex-Product = "$http_x_plex_product";
        X-Plex-Token = "$http_x_plex_token";
        X-Plex-Version = "$http_x_plex_version";
        X-Plex-Nocache = "$http_x_plex_nocache";
        X-Plex-Provides = "$http_x_plex_provides";
        X-Plex-Device-Vendor = "$http_x_plex_device_vendor";
        X-Plex-Model = "$http_x_plex_model";
      };
      locations = {
        "/" = {
          proxy = {
            enable = true;
            inherit headers;
          };
        };
        "/websockets/" = {
          proxy = {
            enable = true;
            websocket.enable = true;
            inherit headers;
          };
        };
      };
      name.shortServer = mkDefault "plex";
      copyFromVhost = mkDefault "plex";
    in {
      plex = {
        inherit name locations extraConfig;
        proxy.upstream = mkDefault upstreamName;
        listen' = {
          http = { };
          https.ssl = true;
          external = {
            enable = mkDefault false;
            port = mkDefault 32400;
            extraParameters = [ "default_server" ];
          };
        };
      };
      plex'local = {
        inherit name locations extraConfig;
        ssl.cert = {
          inherit copyFromVhost;
        };
        proxy = {
          inherit copyFromVhost;
        };
        local.enable = true;
      };
    };
  };
  config.networking.firewall.allowedTCPPorts = let
    inherit (nginx.virtualHosts.plex) listen';
  in mkIf listen'.external.enable [
    listen'.external.port
  ];
}
