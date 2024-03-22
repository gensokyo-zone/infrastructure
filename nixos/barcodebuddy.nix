{config, lib, ...}: let
  inherit (lib.modules) mkIf mkMerge mkAfter mkDefault;
  inherit (config.services) nginx;
  cfg = config.services.barcodebuddy;
in {
  config.services.barcodebuddy = {
    enable = mkDefault true;
    hostName = mkDefault "barcodebuddy";
    reverseProxy.enable = mkDefault true;
    settings = {
      EXTERNAL_GROCY_URL = "https://grocy.${config.networking.domain}";
      DISABLE_AUTHENTICATION = true;
    };
    nginxPhpConfig = mkMerge [
      ''
        include ${config.sops.secrets.barcodebuddy-fastcgi-params.path};
      ''
      (mkIf nginx.virtualHosts.barcodebuddy.proxied.enabled (mkAfter ''
        set $bbuddy_https "";
        if ($x_scheme = https) {
          set $bbuddy_https 1;
        }
        fastcgi_param HTTPS $bbuddy_https if_not_empty;
        fastcgi_param REQUEST_SCHEME $x_scheme;
        fastcgi_param HTTP_HOST $x_forwarded_host;
      ''))
    ];
  };
  config.services.nginx.virtualHosts.barcodebuddy = mkIf cfg.enable {
    proxied.xvars.enable = true;
    vouch = {
      enable = true;
      requireAuth = false;
    };
    name.shortServer = mkDefault "bbuddy";
    locations = {
      "= /api/index.php" = {
        vouch.requireAuth = false;
        extraConfig = cfg.nginxPhpConfig;
      };
      "~ \\.php$" = {
        vouch.requireAuth = true;
      };
    };
  };
  config.users.users.barcodebuddy = mkIf cfg.enable {
    uid = 912;
  };
  config.sops.secrets.barcodebuddy-fastcgi-params = mkIf cfg.enable {
    sopsFile = mkDefault ./secrets/barcodebuddy.yaml;
    owner = mkDefault nginx.user;
  };
}
