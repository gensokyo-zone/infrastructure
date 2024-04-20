{config, access, lib, ...}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) nginx;
  cfg = config.services.barcodebuddy;
in {
  config.services.barcodebuddy = {
    enable = mkDefault true;
    hostName = mkDefault "barcodebuddy'php";
    reverseProxy = {
      enable = mkDefault nginx.virtualHosts.${cfg.hostName}.proxied.enable;
      trustedAddresses = access.cidrForNetwork.allLan.all;
    };
    settings = {
      EXTERNAL_GROCY_URL = "https://grocy.${config.networking.domain}";
      DISABLE_AUTHENTICATION = true;
    };
    nginxPhpSettings.extraConfig = ''
      include ${config.sops.secrets.barcodebuddy-fastcgi-params.path};
    '';
  };
  config.services.nginx.virtualHosts.${cfg.hostName} = mkIf cfg.enable {
    name.shortServer = mkDefault "bbuddy";
    proxied.enable = mkDefault true;
    local.denyGlobal = mkDefault true;
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
