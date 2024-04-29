{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault mkOptionDefault;
  inherit (lib.strings) removePrefix escapeRegex;
  inherit (config.services) grocy nginx;
  inherit (config) networking;
  name.shortServer = mkDefault "grocy";
  serverName = "@grocy_internal";
  serverName'local = "@grocy_internal_local";
  extraConfig = ''
    set $grocy_user "";
  '';
  locations."/" = {
    vouch.setProxyHeader = true;
    proxy = {
      enable = true;
      headers.set.X-Grocy-User = mkOptionDefault "$grocy_user";
    };
  };
  luaAuthHost = { config, xvars, ... }: {
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
        -- elseif ngx.re.match(ngx.var["${removePrefix "$" (xvars.get.host)}"], [[grocy\.(local|tail)\.${escapeRegex networking.domain}$]]) then
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
    vouch.enable = true;
    virtualHosts = {
      grocy'php = mkIf grocy.enable {
        inherit serverName;
        proxied.enable = true;
        local.denyGlobal = true;
      };
      grocy = mkMerge [ luaAuthHost {
        inherit name extraConfig locations;
        vouch.enable = true;
        proxy = {
          upstream = mkIf grocy.enable (mkDefault
            "nginx'proxied"
          );
          host = mkDefault serverName;
        };
      } ];
      grocy'local = {
        inherit name;
        local.enable = mkDefault true;
        ssl.cert.copyFromVhost = "grocy";
        proxy = {
          upstream = mkDefault "nginx'proxied";
          host = nginx.virtualHosts.grocy'local'int.serverName;
        };
        locations."/" = {
          proxy.enable = true;
        };
      };
      grocy'local'int = mkMerge [ luaAuthHost {
        # internal proxy workaround for http2 lua compat issues
        serverName = serverName'local;
        inherit name extraConfig locations;
        proxy = {
          upstream = mkDefault nginx.virtualHosts.grocy.proxy.upstream;
          host = mkDefault nginx.virtualHosts.grocy.proxy.host;
        };
        proxied.enable = true;
        vouch = {
          enable = true;
          localSso.enable = true;
        };
      } ];
    };
  };
}
