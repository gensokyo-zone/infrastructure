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
    nginxConfig = let
      xvars = nginx.virtualHosts.barcodebuddy'php.xvars.lib;
    in mkMerge [
      ''
        include ${config.sops.secrets.barcodebuddy-fastcgi-params.path};
      ''
      (mkIf cfg.reverseProxy.enable (mkAfter ''
        set $bbuddy_https "";
        if (${xvars.get.scheme} = https) {
          set $bbuddy_https 1;
        }
        fastcgi_param HTTPS $bbuddy_https if_not_empty;
        fastcgi_param REQUEST_SCHEME ${xvars.get.scheme};
        fastcgi_param HTTP_HOST ${xvars.get.host};
      ''))
    ];
  };
  config.services.nginx.virtualHosts.barcodebuddy'php = mkIf cfg.enable {
    proxied.enable = cfg.reverseProxy.enable;
    name.shortServer = mkDefault "bbuddy";
  };
  config.users.users.barcodebuddy = mkIf cfg.enable {
    uid = 912;
  };
  config.systemd.services = let
    gensokyo-zone.sharedMounts.barcodebuddy.path = mkDefault cfg.dataDir;
  in mkIf cfg.enable {
    phpfpm-barcodebuddy = {
      inherit gensokyo-zone;
    };
    bbuddy-websocket = mkIf cfg.screen.enable {
      inherit gensokyo-zone;
    };
  };
  config.sops.secrets.barcodebuddy-fastcgi-params = mkIf cfg.enable {
    sopsFile = mkDefault ./secrets/barcodebuddy.yaml;
    owner = mkDefault nginx.user;
  };
}
