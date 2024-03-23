{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault;
  inherit (lib.strings) escapeRegex;
  inherit (config.services) grocy nginx;
  inherit (config) networking;
  name.shortServer = mkDefault "grocy";
  serverName = "@grocy_internal";
  serverName'local = "@grocy_internal_local";
  extraConfig = ''
    set $x_proxy_host ${serverName};
    set $grocy_user "";
  '';
  location = {
    vouch.setProxyHeader = true;
    proxy.headers.enableRecommended = true;
    extraConfig = ''
      proxy_set_header X-Grocy-User $grocy_user;
    '';
  };
  luaAuthHost = { config, ... }: {
    vouch.auth.lua = {
      enable = true;
      accessRequest = ''
        local grocy_apikey = ngx.var["http_grocy_api_key"]
        if grocy_apikey ~= nil and ngx.re.match(ngx.var["request_uri"], "^/api(/|$)") then
          -- bypass authentication and let grocy decide...
          -- if the API key is valid, the middleware will use its user instead
          -- if the API key is invalid, the middleware will fall back to asking for a password
          ngx.ctx.auth_res = {
            status = ngx.HTTP_OK,
            header = { },
          }
        -- elseif ngx.re.match(ngx.var["x_forwarded_host"], [[grocy\.(local|tail)\.${escapeRegex networking.domain}$]]) then
        --   ngx.ctx.auth_res = {
        --     status = ngx.HTTP_OK,
        --     header = { },
        --   }
        --   ngx.var["grocy_user"] = "guest"
        else
          ngx.ctx.auth_res = ngx.location.capture("${config.vouch.auth.requestLocation}")
        end
      '';
    };
  };
in {
  config.services.nginx = {
    lua.http.enable = true;
    virtualHosts = {
      grocy'php = mkIf grocy.enable {
        inherit serverName;
      };
      grocy = mkMerge [ luaAuthHost {
        inherit name extraConfig;
        vouch.enable = true;
        locations."/" = mkMerge [ location {
          proxyPass = mkIf (grocy.enable) (mkDefault
            "http://localhost:${toString nginx.defaultHTTPListenPort}"
          );
        } ];
      } ];
      grocy'local = {
        inherit name;
        local.enable = mkDefault true;
        ssl.cert.copyFromVhost = "grocy";
        locations."/" = {
          proxy.headers.enableRecommended = true;
          proxyPass = mkDefault "http://localhost:${toString nginx.defaultHTTPListenPort}";
        };
        extraConfig = ''
          set $x_proxy_host ${serverName'local};
        '';
      };
      grocy'local'int = mkMerge [ luaAuthHost {
        # internal proxy workaround for http2 lua compat issues
        serverName = serverName'local;
        inherit name extraConfig;
        proxied.enable = true;
        vouch.enable = true;
        locations."/" = mkMerge [ location {
          proxyPass = mkDefault nginx.virtualHosts.grocy.locations."/".proxyPass;
        } ];
      } ];
    };
  };
}
