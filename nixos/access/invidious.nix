{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkBefore mkDefault;
  inherit (lib.strings) replaceStrings concatStringsSep concatMapStringsSep escapeRegex;
  inherit (config.services.nginx) virtualHosts;
  cfg = config.services.invidious;
in {
  config.services.nginx = {
    virtualHosts = let
      invidiousDomains =
        virtualHosts.invidious.allServerNames
        ++ virtualHosts.invidious'local.allServerNames;
      contentSecurityPolicy' = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; manifest-src 'self'; media-src 'self' blob: https://*.googlevideo.com:443 https://*.youtube.com:443; child-src 'self' blob:; frame-src 'self'; frame-ancestors 'none'";
      contentSecurityPolicy = replaceStrings ["'self'"] ["'self' ${concatStringsSep " " invidiousDomains}"] contentSecurityPolicy';
      extraConfig = mkBefore ''
        # Some players don't reopen a socket and playback stops totally instead of resuming after an extended pause
        send_timeout 100m;
        # Buffering off send to the client as soon as the data is received from invidious.
        proxy_redirect off;
        proxy_buffering off;
        set $x_proxy_host $x_forwarded_host;
      '';
      location = {
        proxy.websocket.enable = true;
        proxy.headers.enableRecommended = true;
        extraConfig = ''
          proxy_hide_header content-security-policy;
          add_header content-security-policy "${contentSecurityPolicy}";
          proxy_cookie_domain ${virtualHosts.invidious.serverName} $x_forwarded_host;
        '';
      };
      name.shortServer = mkDefault "yt";
      kTLS = mkDefault true;
      localDomains = virtualHosts.invidious'local.allServerNames;
    in {
      invidious = {
        # lua can't handle HTTP 2.0 requests, so layer it behind another proxy...
        inherit name extraConfig kTLS;
        locations."/" = {
          proxyPass = "http://localhost:${toString config.services.nginx.defaultHTTPListenPort}";
          proxy.headers.enableRecommended = true;
          extraConfig = ''
            proxy_http_version 1.1;
            set $x_proxy_host ${virtualHosts.invidious'int.serverName};
            set $invidious_req_check $x_scheme:$request_uri;
            if ($invidious_req_check = "http:/") {
              return ${toString virtualHosts.invidious.redirectCode} https://$x_forwarded_host$request_uri;
            }
          '';
        };
      };
      invidious'int = { config, ... }: {
        serverName = "@invidious_internal";
        proxied.enable = true;
        local.denyGlobal = true;
        # TODO: consider disabling registration then redirecting to login if `SID` cookie is unset instead of using vouch
        vouch = {
          enable = true;
          requireAuth = false;
          auth.lua = {
            enable = true;
            accessRequest = ''
              local invidious_auth = ngx.var["http_authentication"]
              local invidious_agent = ngx.var["http_user_agent"]
              local invidious_app_auth = invidious_auth ~= nil and ngx.re.match(invidious_auth, [[":]])
              local invidious_app = invidious_agent ~= nil and ngx.re.match(invidious_agent, [[Dart/\d\.\d \(dart:io\)]])
              local invidious_api_request = ngx.re.match(ngx.var.request_uri, [[^/(api/v\d|vi/)]])
              local is_local_request = ngx.re.match(ngx.var["http_referer"], [[^https?://(${concatMapStringsSep "|" escapeRegex localDomains})/]])
              if invidious_app_auth or (invidious_app and invidious_api_request) or is_local_request then
                -- bypass vouch if the app is using token auth...
                ngx.ctx.auth_res = {
                  status = ngx.HTTP_OK,
                  header = { },
                }
              else
                ngx.ctx.auth_res = ngx.location.capture("${config.vouch.auth.requestLocation}")
              end
            '';
          };
        };
        locations = {
          "/" = mkMerge [
            location
            {
              vouch.requireAuth = true;
              proxyPass = mkIf cfg.enable (
                mkDefault "http://localhost:${toString cfg.port}"
              );
            }
          ];
        };
        inherit extraConfig;
      };
      invidious'local = {
        local.enable = true;
        ssl.cert.copyFromVhost = "invidious";
        locations."/" = mkMerge [
          location
          {
            proxyPass = mkDefault virtualHosts.invidious'int.locations."/".proxyPass;
          }
        ];
        inherit name extraConfig kTLS;
      };
    };
    lua.http.enable = true;
  };
}
