{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  cfg = config.services.plex;
  access = config.services.nginx.access.plex;
in {
  options.services.nginx.access.plex = with lib.types; {
    url = mkOption {
      type = str;
    };
    domain = mkOption {
      type = str;
      default = "plex.${config.networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "plex.local.${config.networking.domain}";
    };
  };
  config.services.nginx = {
    access.plex = mkIf cfg.enable {
      url = mkOptionDefault "http://localhost:32400";
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
      location = {
        proxy.websocket.enable = true;
        proxyPass = access.url;
      };
    in {
      ${access.domain} = {
        locations."/" = location;
        kTLS = mkDefault true;
        inherit extraConfig;
      };
      ${access.localDomain} = {
        local.enable = true;
        locations."/" = location;
        kTLS = mkDefault true;
        inherit extraConfig;
      };
    };
  };
}
