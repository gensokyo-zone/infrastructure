{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  inherit (config.services) nginx;
  cfg = config.services.plex;
  access = nginx.access.plex;
in {
  options.services.nginx.access.plex = with lib.types; {
    url = mkOption {
      type = str;
    };
    externalPort = mkOption {
      type = nullOr port;
      default = null;
    };
  };
  config.services.nginx = {
    access.plex = mkIf cfg.enable {
      url = mkOptionDefault "http://localhost:${toString cfg.port}";
    };
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
        proxy.websocket.enable = true;
        proxyPass = access.url;
      };
      name.shortServer = mkDefault "plex";
      kTLS = mkDefault true;
    in {
      plex = {
        inherit name locations extraConfig kTLS;
        listenPorts = {
          http = { };
          https.ssl = true;
          external = {
            enable = mkDefault (access.externalPort != null);
            port = mkDefault access.externalPort;
            extraParameters = [ "default_server" ];
          };
        };
      };
      plex'local = {
        inherit name locations extraConfig kTLS;
        local.enable = true;
      };
    };
  };
  config.networking.firewall.allowedTCPPorts = mkIf (access.externalPort != null) [
    access.externalPort
  ];
}
