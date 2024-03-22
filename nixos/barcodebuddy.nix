{config, lib, ...}: let
  inherit (lib.modules) mkDefault;
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
    nginxPhpConfig = ''
      include ${config.sops.secrets.barcodebuddy-fastcgi-params.path};
    '';
  };
  config.services.nginx.virtualHosts.barcodebuddy = {
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
  config.sops.secrets.barcodebuddy-fastcgi-params = {
    sopsFile = mkDefault ./secrets/barcodebuddy.yaml;
    owner = mkDefault nginx.user;
  };
}
