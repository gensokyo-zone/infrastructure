{config, lib, ...}: let
  inherit (lib.modules) mkIf mkDefault mkAfter;
  inherit (lib.strings) escapeRegex;
  inherit (config.services) nginx;
  inherit (config) networking;
in {
  config = {
    services.grocy = {
      enable = mkDefault true;
      hostName = "grocy";
      nginx.enableSSL = false;
      settings = {
        currency = mkDefault "CAD";
      };
    };
    services.nginx = let
      name.shortServer = mkDefault "grocy";
      lua.access.block = ''
        local grocy_user_pat = "^([^@]+)@.*$"
        if ngx.re.match(ngx.var.auth_resp_x_vouch_user, grocy_user_pat) then
          ngx.var["grocy_user"] = ngx.re.sub(ngx.var.auth_resp_x_vouch_user, grocy_user_pat, "$1", "o") or "guest"
        end
      '';
      extraConfig = mkAfter ''
        set $grocy_user guest;
        set $grocy_middleware Grocy\Middleware\ReverseProxyAuthMiddleware;

        fastcgi_param GENSO_GROCY_USER $grocy_user;
        fastcgi_param GROCY_REVERSE_PROXY_AUTH_HEADER GENSO_GROCY_USER;
        fastcgi_param GROCY_REVERSE_PROXY_AUTH_USE_ENV true;

        fastcgi_param GROCY_AUTH_CLASS $grocy_middleware;
      '';
    in {
      lua.http.enable = true;
      virtualHosts = {
        grocy = {config, ...}: {
          inherit name;
          vouch = {
            enable = true;
            requireAuth = false;
            auth.lua = {
              enable = true;
              accessRequest = ''
                local grocy_apikey = ngx.var["http_grocy_api_key"]
                if grocy_apikey ~= nil and ngx.re.match(ngx.var.request_uri, "^/api(/|$)") then
                  -- bypass authentication and let grocy decide...
                  -- if the API key is valid, the middleware will use its user instead
                  -- if the API key is invalid, the middleware will fall back to the (invalid/empty) user string
                  ngx.ctx.auth_res = {
                    status = ngx.HTTP_OK,
                    header = { },
                  }
                  ngx.var["grocy_user"] = ""
                else
                  ngx.ctx.auth_res = ngx.location.capture("${config.vouch.auth.requestLocation}")
                end
              '';
            };
          };
          locations."~ \\.php$" = mkIf nginx.virtualHosts.grocy.vouch.enable {
            vouch.requireAuth = true;
            inherit extraConfig lua;
          };
        };
      };
    };
  };
}
