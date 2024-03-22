{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) grocy nginx;
  name.shortServer = mkDefault "grocy";
in {
  config.services.nginx.virtualHosts = {
    grocy = {
      inherit name;
      locations."/" = mkIf (!grocy.enable) {
        proxy.headers.enableRecommended = true;
        extraConfig = ''
          set $x_proxy_host ${nginx.virtualHosts.grocy.serverName};
        '';
      };
    };
    grocy'local = {
      inherit name;
      ssl.cert.copyFromVhost = "grocy";
      local.enable = mkDefault true;
      locations."/" = mkIf (!grocy.enable) {
        proxyPass = mkDefault (if grocy.enable
          then "http://localhost:${toString nginx.defaultHTTPListenPort}"
          else nginx.virtualHosts.grocy.locations."/".proxyPass
        );
        proxy.headers.enableRecommended = true;
        extraConfig = ''
          set $x_proxy_host ${nginx.virtualHosts.grocy.serverName};
          proxy_redirect $x_scheme://${nginx.virtualHosts.grocy.serverName}/ $x_scheme://$x_host/;
        '';
      };
    };
  };
}
