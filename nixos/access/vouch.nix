{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault mkOptionDefault;
  inherit (config.services) tailscale;
  cfg = config.services.vouch-proxy;
  access = config.services.nginx.access.vouch;
in {
  options.services.nginx.access.vouch = with lib.types; {
    url = mkOption {
      type = str;
    };
    domain = mkOption {
      type = str;
      default = "login.${config.networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "login.local.${config.networking.domain}";
    };
    tailDomain = mkOption {
      type = str;
      default = "login.tail.${config.networking.domain}";
    };
    useACMEHost = mkOption {
      type = nullOr str;
      default = null;
    };
  };
  config.services.nginx = {
    access.vouch = mkIf cfg.enable {
      url = let
        inherit (cfg.settings.vouch) listen;
        host = if listen == "0.0.0.0" || listen == "[::]" then "localhost" else listen;
      in mkOptionDefault "http://${host}:${toString cfg.port}";
    };
    virtualHosts = let
      location = {
        proxy.websocket.enable = true;
        proxyPass = access.url;
        recommendedProxySettings = false;
      };
    in {
      ${access.localDomain} = mkIf (access.useACMEHost != null) {
        local.enable = true;
        locations."/" = location;
        useACMEHost = mkDefault access.useACMEHost;
        forceSSL = true;
      };
      ${access.tailDomain} = mkIf tailscale.enable {
        local.enable = true;
        locations."/" = location;
        useACMEHost = mkDefault access.useACMEHost;
        addSSL = mkIf (access.useACMEHost != null) (mkDefault true);
      };
    };
  };
}
