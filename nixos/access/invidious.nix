{
  config,
  system,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkBefore mkDefault;
  inherit (lib.strings) replaceStrings concatStringsSep concatMapStringsSep escapeRegex;
  inherit (config.services) nginx;
  cfg = config.services.invidious;
  upstreamName = "invidious'access";
  upstreamNginx = "invidious'access'nginx";
in {
  config.services.nginx = {
    upstreams' = {
      ${upstreamName}.servers = {
        local = {
          enable = mkDefault cfg.enable;
          addr = mkDefault "localhost";
          port = mkIf cfg.enable (mkDefault cfg.port);
        };
        service = { upstream, ... }: {
          enable = mkIf upstream.servers.local.enable (mkDefault false);
          accessService = {
            name = "invidious";
          };
        };
      };
      ${upstreamNginx} = {
        enable = mkDefault nginx.virtualHosts.invidious'int.enable;
        host = mkDefault nginx.virtualHosts.invidious'int.serverName;
        servers.local = {
          accessService = {
            inherit (nginx.upstreams'.nginx'proxied.servers.local.accessService) system name id port;
          };
        };
      };
    };
    virtualHosts = let
      invidiousDomains =
        nginx.virtualHosts.invidious.allServerNames
        ++ nginx.virtualHosts.invidious'local.allServerNames;
      contentSecurityPolicy' = "default-src 'self'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; manifest-src 'self'; media-src 'self' blob: https://*.googlevideo.com:443 https://*.youtube.com:443; child-src 'self' blob:; frame-src 'self'; frame-ancestors 'none'";
      contentSecurityPolicy = replaceStrings ["'self'"] ["'self' ${concatStringsSep " " invidiousDomains}"] contentSecurityPolicy';
      extraConfig = mkBefore ''
        # Some players don't reopen a socket and playback stops totally instead of resuming after an extended pause
        send_timeout 100m;
        # Buffering off send to the client as soon as the data is received from invidious.
        proxy_redirect off;
        proxy_buffering off;
      '';
      location = { xvars, ... }: {
        proxy = {
          enable = true;
          websocket.enable = true;
          headers.hide.content-security-policy = true;
        };
        headers.set.content-security-policy = contentSecurityPolicy;
        extraConfig = ''
          proxy_cookie_domain ${nginx.virtualHosts.invidious.serverName} ${xvars.get.host};
        '';
      };
      name.shortServer = mkDefault "yt";
      localDomains = nginx.virtualHosts.invidious'local.allServerNames;
    in {
      invidious = {
        # lua can't handle HTTP 2.0 requests, so layer it behind another proxy...
        inherit name extraConfig;
        proxy.upstream = upstreamNginx;
        locations."/" = { xvars, virtualHost, ... }: {
          proxy.enable = true;
          extraConfig = ''
            proxy_http_version 1.1;
            set $invidious_req_check ${xvars.get.scheme}:$request_uri;
            if ($invidious_req_check = "http:/") {
              return ${toString virtualHost.redirectCode} https://${xvars.get.host}$request_uri;
            }
          '';
        };
      };
      invidious'int = { config, xvars, ... }: {
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
        proxy = {
          host = mkDefault xvars.get.host;
          upstream = mkDefault upstreamName;
        };
        locations = {
          "/" = mkMerge [
            location
            {
              vouch.requireAuth = true;
            }
          ];
        };
        inherit extraConfig;
      };
      invidious'local = { xvars, ... }: {
        local.enable = true;
        ssl.cert.copyFromVhost = "invidious";
        proxy = {
          copyFromVhost = mkDefault "invidious'int";
          host = mkDefault xvars.get.host;
        };
        locations."/" = location;
        inherit name extraConfig;
      };
    };
    lua.http.enable = true;
  };
}
