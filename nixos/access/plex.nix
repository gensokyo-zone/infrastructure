{
  config,
  lib,
  access,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) nginx;
  cfg = config.services.plex;
in {
  config.services.nginx = {
    virtualHosts = let
      extraConfig = ''
        # Some players don't reopen a socket and playback stops totally instead of resuming after an extended pause
        send_timeout 100m;
        # Plex headers
        proxy_set_header X-Plex-Client-Identifier $http_x_plex_client_identifier;
        proxy_set_header X-Plex-Device $http_x_plex_device;
        proxy_set_header X-Plex-Device-Name $http_x_plex_device_name;
        proxy_set_header X-Plex-Platform $http_x_plex_platform;
        proxy_set_header X-Plex-Platform-Version $http_x_plex_platform_version;
        proxy_set_header X-Plex-Product $http_x_plex_product;
        proxy_set_header X-Plex-Token $http_x_plex_token;
        proxy_set_header X-Plex-Version $http_x_plex_version;
        proxy_set_header X-Plex-Nocache $http_x_plex_nocache;
        proxy_set_header X-Plex-Provides $http_x_plex_provides;
        proxy_set_header X-Plex-Device-Vendor $http_x_plex_device_vendor;
        proxy_set_header X-Plex-Model $http_x_plex_model;
        # Buffering off send to the client as soon as the data is received from Plex.
        proxy_redirect off;
        proxy_buffering off;
      '';
      locations."/" = {
        proxy.websocket.enable = mkDefault true;
        proxyPass = mkDefault (if cfg.enable
          then "http://localhost:${toString cfg.port}"
          else access.proxyUrlFor { serviceName = "plex"; }
        );
      };
      name.shortServer = mkDefault "plex";
      kTLS = mkDefault true;
    in {
      plex = {
        inherit name locations extraConfig kTLS;
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
        inherit name locations extraConfig kTLS;
        ssl.cert.copyFromVhost = "plex";
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
