{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkBefore mkDefault;
  cfg = config.services.grocy;
in {
  config = {
    services.grocy = {
      enable = mkDefault true;
      hostName = "grocy'php";
      nginx.enableSSL = false;
      settings = {
        currency = mkDefault "CAD";
      };
    };
    services.nginx.virtualHosts = {
      grocy'php = mkIf cfg.enable ({config, ...}: let
        authHeader = "GENSO_GROCY_USER";
        extraConfig = mkMerge [
          (mkBefore ''
            set $grocy_middleware Grocy\Middleware\DefaultAuthMiddleware;
            set $grocy_user "";
          '')
          (mkIf config.proxied.enable ''
            set $grocy_user guest;
            set $grocy_auth_header ${authHeader};
            set $grocy_auth_env true;

            if ($http_grocy_api_key) {
              set $grocy_user "";
            }
            if ($request_uri ~ "^/api(/.*|)$") {
              set $grocy_user "";
            }
            if ($http_x_vouch_user ~ "^([^@]+)@.*$") {
              set $grocy_user $1;
            }
            if ($http_x_grocy_user) {
              #set $grocy_auth_header X-Grocy-User;
              #set $grocy_auth_env false;
              set $grocy_user $http_x_grocy_user;
            }

            if ($grocy_user) {
              set $grocy_middleware Grocy\Middleware\ReverseProxyAuthMiddleware;
            }
          '')
        ];
      in {
        name.shortServer = mkDefault "grocy";
        locations."~ \\.php$" = {
          fastcgi = {
            enable = true;
            phpfpmPool = "grocy";
            socket = null;
            includeDefaults = false;
            params = mkMerge [
              {
                GROCY_AUTH_CLASS = "$grocy_middleware";
              }
              (mkIf config.proxied.enable {
                GROCY_REVERSE_PROXY_AUTH_USE_ENV = "$grocy_auth_env";
                GROCY_REVERSE_PROXY_AUTH_HEADER = "$grocy_auth_header";
                ${authHeader} = "$grocy_user";
              })
            ];
          };
          inherit extraConfig;
        };
      });
    };
    users.users.grocy = mkIf cfg.enable {
      uid = 911;
    };
    systemd.services = let
      gensokyo-zone.sharedMounts.grocy.path = mkDefault cfg.dataDir;
    in
      mkIf cfg.enable {
        grocy-setup = {
          inherit gensokyo-zone;
        };
        phpfpm-grocy = {
          inherit gensokyo-zone;
        };
      };
  };
}
