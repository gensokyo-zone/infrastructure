{config, lib, ...}: let
  inherit (lib.modules) mkIf mkMerge mkAfter mkDefault;
  inherit (config.services) nginx;
  cfg = config.services.barcodebuddy;
in {
  config.services.barcodebuddy = {
    enable = mkDefault true;
    hostName = mkDefault "barcodebuddy'php";
    reverseProxy.enable = mkDefault true;
    settings = {
      EXTERNAL_GROCY_URL = "https://grocy.${config.networking.domain}";
      DISABLE_AUTHENTICATION = true;
    };
    nginxConfig = mkMerge [
      ''
        include ${config.sops.secrets.barcodebuddy-fastcgi-params.path};
      ''
      (mkIf cfg.reverseProxy.enable (mkAfter ''
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
  config.services.nginx.virtualHosts.barcodebuddy'php = mkIf cfg.enable {
    proxied = {
      enable = cfg.reverseProxy.enable;
      xvars.enable = true;
    };
    name.shortServer = mkDefault "bbuddy";
  };
  config.users.users.barcodebuddy = mkIf cfg.enable {
    uid = 912;
  };
  config.systemd.services = let
    BindPaths = [
      "/mnt/shared/barcodebuddy:${cfg.dataDir}"
    ];
  in mkIf cfg.enable {
    phpfpm-barcodebuddy = {
      serviceConfig = {
        inherit BindPaths;
      };
    };
    bbuddy-websocket = mkIf cfg.screen.enable {
      serviceConfig = {
        inherit BindPaths;
      };
    };
  };
  config.sops.secrets.barcodebuddy-fastcgi-params = mkIf cfg.enable {
    sopsFile = mkDefault ./secrets/barcodebuddy.yaml;
    owner = mkDefault nginx.user;
  };
}
