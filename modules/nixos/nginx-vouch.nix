{
  config,
  lib,
  ...
}:
with lib; let
  inherit (config.services) vouch-proxy;
in {
  options = with types; {
    services.nginx.virtualHosts = let
      vouchModule = { config, ... }: {
        options = {
          vouch = {
            enable = mkEnableOption "vouch auth proxy";
            proxyOrigin = mkOption {
              type = str;
            };
            authUrl = mkOption {
              type = str;
            };
            url = mkOption {
              type = str;
            };
          };
        };
        config = mkMerge [
          {
            vouch = mkIf vouch-proxy.enable {
              proxyOrigin = let
                inherit (vouch-proxy.settings.vouch) listen port;
              in mkOptionDefault "http://${listen}:${toString port}";
              authUrl = mkOptionDefault vouch-proxy.authUrl;
              url = mkOptionDefault vouch-proxy.url;
            };
          }
          (mkIf config.vouch.enable {
            extraConfig = ''
              auth_request /validate;
              error_page 401 = @error401;
            '';
            locations = {
              "/" = {
                extraConfig = ''
                  add_header Access-Control-Allow-Origin ${config.vouch.url};
                  add_header Access-Control-Allow-Origin ${config.vouch.authUrl};
                  proxy_set_header X-Vouch-User $auth_resp_x_vouch_user;
                '';
              };
              "@error401" = {
                extraConfig = ''
                  return 302 ${config.vouch.url}/login?url=$scheme://$http_host$request_uri&vouch-failcount=$auth_resp_failcount&X-Vouch-Token=$auth_resp_jwt&error=$auth_resp_err;
                '';
              };
              "/validate" = {
                recommendedProxySettings = false;
                proxyPass = "${config.vouch.proxyOrigin}/validate";
                extraConfig = ''
                  proxy_set_header Host $host;
                  proxy_pass_request_body off;
                  proxy_set_header Content-Length "";
                  auth_request_set $auth_resp_x_vouch_user $upstream_http_x_vouch_user;
                  auth_request_set $auth_resp_jwt $upstream_http_x_vouch_jwt;
                  auth_request_set $auth_resp_err $upstream_http_x_vouch_err;
                  auth_request_set $auth_resp_failcount $upstream_http_x_vouch_failcount;
                '';
              };
            };
          })
        ];
      };
    in mkOption {
      type = attrsOf (submodule vouchModule);
    };
  };
}
