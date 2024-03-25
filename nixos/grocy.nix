{config, lib, ...}: let
  inherit (lib.modules) mkIf mkDefault mkAfter;
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
    services.nginx = let
      extraConfig = mkAfter ''
        set $grocy_user guest;
        set $grocy_middleware Grocy\Middleware\ReverseProxyAuthMiddleware;
        set $grocy_auth_header GENSO_GROCY_USER;
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
        if ($grocy_user = "") {
          set $grocy_middleware Grocy\Middleware\DefaultAuthMiddleware;
        }

        fastcgi_param GROCY_AUTH_CLASS $grocy_middleware;
        fastcgi_param GROCY_REVERSE_PROXY_AUTH_USE_ENV $grocy_auth_env;
        fastcgi_param GROCY_REVERSE_PROXY_AUTH_HEADER $grocy_auth_header;
        fastcgi_param GENSO_GROCY_USER $grocy_user;

        set $grocy_https "";
        if ($x_scheme = https) {
          set $grocy_https 1;
        }
        fastcgi_param HTTP_HOST $x_forwarded_host;
        fastcgi_param REQUEST_SCHEME $x_scheme;
        fastcgi_param HTTPS $grocy_https if_not_empty;
      '';
    in {
      virtualHosts = {
        grocy'php = mkIf cfg.enable ({config, ...}: {
          name.shortServer = mkDefault "grocy";
          proxied = {
            enable = true;
            xvars.enable = true;
          };
          local.denyGlobal = true;
          locations."~ \\.php$" = {
            inherit extraConfig;
          };
        });
      };
    };
    users.users.grocy = mkIf cfg.enable {
      uid = 911;
    };
    systemd.services = let
      gensokyo-zone.sharedMounts.grocy.path = mkDefault cfg.dataDir;
    in mkIf cfg.enable {
      grocy-setup = {
        inherit gensokyo-zone;
      };
      phpfpm-grocy = {
        inherit gensokyo-zone;
      };
    };
  };
}
