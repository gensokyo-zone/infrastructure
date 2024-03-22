{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) barcodebuddy nginx;
  name.shortServer = mkDefault "bbuddy";
  serverName = "@bbuddy_internal";
  extraConfig = ''
    set $x_proxy_host ${serverName};
  '';
in {
  config.services.nginx.virtualHosts = {
    barcodebuddy'php = mkIf barcodebuddy.enable {
      inherit serverName;
      proxied.enable = mkDefault true;
      local.denyGlobal = true;
    };
    barcodebuddy = {
      inherit name extraConfig;
      vouch = {
        enable = true;
        requireAuth = false;
      };
      locations = {
        "/api/" = {
          proxy.headers.enableRecommended = true;
          proxyPass = mkDefault "${nginx.virtualHosts.barcodebuddy.locations."/".proxyPass}/api/";
        };
        "/" = {
          proxy.headers.enableRecommended = true;
          vouch.requireAuth = true;
          proxyPass = mkIf barcodebuddy.enable (mkDefault
            "http://localhost:${toString nginx.defaultHTTPListenPort}"
          );
        };
      };
    };
    barcodebuddy'local = {
      inherit name extraConfig;
      ssl.cert.copyFromVhost = "barcodebuddy";
      local.enable = mkDefault true;
      locations."/" = {
        proxy.headers.enableRecommended = true;
        proxyPass = mkDefault nginx.virtualHosts.barcodebuddy.locations."/".proxyPass;
        extraConfig = ''
          proxy_redirect $x_scheme://${serverName}/ $x_scheme://$x_host/;
        '';
      };
    };
  };
}
