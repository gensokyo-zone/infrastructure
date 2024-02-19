{
  config,
  lib,
  ...
}:
let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkDefault;
  inherit (config) networking;
  inherit (config.services) vouch-proxy tailscale;
  vouchModule = { config, ... }: {
    options = with lib.types; {
      vouch = {
        enable = mkEnableOption "vouch auth proxy";
        proxyOrigin = mkOption {
          type = str;
          default = "https://login.local.${networking.domain}";
        };
        authUrl = mkOption {
          type = str;
          default = "https://id.${networking.domain}";
        };
        url = mkOption {
          type = str;
          default = "https://login.${networking.domain}";
        };
        localUrl = mkOption {
          type = str;
          default = "https://login.local.${networking.domain}";
        };
        tailDomain = mkOption {
          type = str;
          default = "login.tail.${networking.domain}";
        };
        authRequestDirective = mkOption {
          type = lines;
          default = ''
            auth_request /validate;
          '';
        };
      };
    };
    config = mkMerge [
      {
        vouch = mkIf vouch-proxy.enable {
          proxyOrigin = let
            inherit (vouch-proxy.settings.vouch) listen port;
            host = if listen == "0.0.0.0" || listen == "[::]" then "localhost" else listen;
          in mkDefault "http://${host}:${toString port}";
          authUrl = mkDefault vouch-proxy.authUrl;
          url = mkDefault vouch-proxy.url;
        };
      }
      {
        vouch.proxyOrigin = mkIf (tailscale.enable && !vouch-proxy.enable) (mkDefault
          "http://login.tail.${networking.domain}"
        );
      }
      (mkIf config.vouch.enable {
        extraConfig = ''
          ${config.vouch.authRequestDirective}
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
            extraConfig = let
              localVouchUrl = ''
                if ($http_host ~ "\.local\.${networking.domain}$") {
                  set $vouch_url ${config.vouch.localUrl};
                }
              '';
              tailVouchUrl = ''
                if ($http_host ~ "\.tail\.${networking.domain}$") {
                  set $vouch_url $scheme://${config.vouch.tailDomain};
                }
              '';
            in mkMerge [
              (mkBefore ''
                set $vouch_url ${config.vouch.url};
              '')
              (mkIf (config.local.enable or false) localVouchUrl)
              (mkIf (config.local.enable or false && tailscale.enable) tailVouchUrl)
              ''
                return 302 $vouch_url/login?url=$scheme://$http_host$request_uri&vouch-failcount=$auth_resp_failcount&X-Vouch-Token=$auth_resp_jwt&error=$auth_resp_err;
              ''
            ];
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
in {
  options = with lib.types; {
    services.nginx.virtualHosts = mkOption {
      type = attrsOf (submodule vouchModule);
    };
  };
}
