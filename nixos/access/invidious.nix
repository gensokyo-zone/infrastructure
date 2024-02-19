{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.lists) optional;
  inherit (lib.strings) replaceStrings concatStringsSep;
  inherit (config.services.nginx) virtualHosts;
  inherit (config.services) tailscale;
  cfg = config.services.invidious;
  access = config.services.nginx.access.invidious;
in {
  options.services.nginx.access.invidious = with lib.types; {
    url = mkOption {
      type = str;
    };
    domain = mkOption {
      type = str;
      default = "yt.${config.networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "yt.local.${config.networking.domain}";
    };
    tailDomain = mkOption {
      type = str;
      default = "yt.tail.${config.networking.domain}";
    };
  };
  config.services.nginx = {
    access.invidious = mkIf cfg.enable {
      url = mkOptionDefault "http://localhost:${toString cfg.port}";
    };
    virtualHosts = let
      invidiousDomains = [
        access.domain
        access.localDomain
      ] ++ optional tailscale.enable access.tailDomain;
      contentSecurityPolicy' = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; manifest-src 'self'; media-src 'self' blob: https://*.googlevideo.com:443 https://*.youtube.com:443; child-src 'self' blob:; frame-src 'self'; frame-ancestors 'none'";
      contentSecurityPolicy = replaceStrings [ "'self'" ] [ "'self' ${concatStringsSep " " invidiousDomains}" ] contentSecurityPolicy';
      extraConfig = ''
        # Some players don't reopen a socket and playback stops totally instead of resuming after an extended pause
        send_timeout 100m;
        # Buffering off send to the client as soon as the data is received from invidious.
        proxy_redirect off;
        proxy_buffering off;
      '';
      location = {
        proxy.websocket.enable = true;
        proxyPass = access.url;
        extraConfig = ''
          proxy_hide_header content-security-policy;
          add_header content-security-policy "${contentSecurityPolicy}";
        '';
      };
    in {
      ${access.domain} = { config, ... }: {
        vouch.enable = true;
        locations."/" = location;
        kTLS = mkDefault true;
        inherit extraConfig;
      };
      ${access.localDomain} = { config, ... }: {
        serverAliases = mkIf tailscale.enable [ access.tailDomain ];
        local.enable = true;
        locations."/" = mkMerge [
          location
          {
            extraConfig = ''
              proxy_cookie_domain ${access.domain} $host;
            '';
          }
        ];
        useACMEHost = mkDefault virtualHosts.${access.domain}.useACMEHost;
        addSSL = mkIf (config.useACMEHost != null) (mkDefault true);
        kTLS = mkDefault true;
        inherit extraConfig;
      };
    };
  };
}
