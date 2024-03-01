{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.lists) head;
  inherit (lib.strings) splitString;
  inherit (config.services) nginx tailscale;
  access = nginx.access.freepbx;
  freepbx = config.lib.access.systemFor "freepbx";
in {
  options.services.nginx.access.freepbx = with lib.types; {
    url = mkOption {
      type = str;
      default = "http://${freepbx.access.hostnameForNetwork.local}";
    };
    domain = mkOption {
      type = str;
      default = "pbx.${config.networking.domain}";
    };
    localDomain = mkOption {
      type = str;
      default = "pbx.local.${config.networking.domain}";
    };
    tailDomain = mkOption {
      type = str;
      default = "pbx.tail.${config.networking.domain}";
    };
    useACMEHost = mkOption {
      type = nullOr str;
      default = null;
    };
  };
  config.services.nginx = {
    virtualHosts = let
      proxyScheme = head (splitString ":" access.url);
      extraConfig = ''
        proxy_buffering off;

        set $pbx_scheme $scheme;
        if ($http_x_forwarded_proto) {
          set $pbx_scheme $http_x_forwarded_proto;
        }
        proxy_redirect ${proxyScheme}://$host/ $pbx_scheme://$host/;
      '';
      locations = {
        "/" = {
          proxyPass = access.url;
        };
      };
    in {
      ${access.domain} = {
        vouch.enable = mkDefault true;
        addSSL = mkDefault (access.useACMEHost != null);
        kTLS = mkDefault true;
        useACMEHost = mkDefault access.useACMEHost;
        inherit locations extraConfig;
      };
      ${access.localDomain} = {
        serverAliases = mkIf tailscale.enable [ access.tailDomain ];
        useACMEHost = mkDefault access.useACMEHost;
        addSSL = mkDefault (access.useACMEHost != null);
        kTLS = mkDefault true;
        local.enable = true;
        inherit locations extraConfig;
      };
    };
  };
}
