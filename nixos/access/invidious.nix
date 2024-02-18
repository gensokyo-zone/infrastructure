{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  cfg = config.services.invidious;
  access = config.services.nginx.access.invidious;
in {
  options.services.nginx.access.invidious = with lib.types; {
    url = mkOption {
      type = str;
    };
    domain = mkOption {
      type = str;
      default = "invidious.${config.networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "invidious.local.${config.networking.domain}";
    };
  };
  config.services.nginx = {
    access.invidious = mkIf cfg.enable {
      url = mkOptionDefault "http://localhost:${cfg.port}";
    };
    virtualHosts = let
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
      };
    in {
      ${access.domain} = {
        vouch.enable = true;
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
