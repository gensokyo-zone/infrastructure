{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib.lib) mkAlmostOptionDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkAfter mkOptionDefault;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.strings) toLower replaceStrings;
  inherit (config) networking;
  inherit (config.services) vouch-proxy nginx tailscale;
  inherit (nginx) vouch;
  locationModule = {config, virtualHost, ...}: {
    options.vouch = with lib.types; {
      requireAuth = mkEnableOption "require auth to access this location";
      setProxyHeader = mkOption {
        type = bool;
        default = false;
        description = "proxy_set_header X-Vouch-User";
      };
    };
    config = let
      enableVouchLocal = virtualHost.vouch.localSso.enable;
      enableVouchTail = enableVouchLocal && tailscale.enable;
      allowOrigin = url: "add_header Access-Control-Allow-Origin ${url};";
    in mkIf config.vouch.requireAuth {
      lua = mkIf virtualHost.vouch.auth.lua.enable {
        access.block = mkMerge [
          (mkBefore virtualHost.vouch.auth.lua.accessRequest)
          (mkBefore virtualHost.vouch.auth.lua.accessVariables)
          (mkBefore virtualHost.vouch.auth.lua.accessLogic)
        ];
      };
      proxied.xvars.enable = mkIf (enableVouchTail || virtualHost.vouch.auth.lua.enable) true;
      extraConfig = assert virtualHost.vouch.enable; mkMerge [
        (mkIf (!virtualHost.vouch.requireAuth) virtualHost.vouch.auth.requestDirective)
        (allowOrigin vouch.url)
        (allowOrigin vouch.authUrl)
        (mkIf enableVouchLocal (allowOrigin vouch.localUrl))
        (mkIf enableVouchTail (allowOrigin "$x_scheme://${vouch.tailDomain}"))
        (mkIf config.vouch.setProxyHeader ''
          proxy_set_header X-Vouch-User $auth_resp_x_vouch_user;
        '')
      ];
    };
  };
  hostModule = {config, ...}: let
    cfg = config.vouch;
    mkHeaderVar = header: toLower (replaceStrings [ "-" ] [ "_" ] header);
    mkUpstreamVar = header: "\$upstream_http_${mkHeaderVar header}";
  in {
    options = with lib.types; {
      locations = mkOption {
        type = attrsOf (submodule locationModule);
      };
      vouch = {
        enable = mkEnableOption "vouch auth proxy";
        localSso.enable = mkEnableOption "lan-local vouch" // {
          default = vouch.localSso.enable && config.local.enable;
        };
        requireAuth = mkEnableOption "require auth to access this host" // {
          default = true;
        };
        auth = {
          lua = {
            enable = mkEnableOption "lua";
            accessRequest = mkOption {
              type = lines;
              default = ''
                ngx.ctx.auth_res = ngx.location.capture("${cfg.auth.requestLocation}")
              '';
            };
            accessVariables = mkOption {
              type = lines;
            };
            accessLogic = mkOption {
              type = lines;
            };
          };
          errorLocation = mkOption {
            type = nullOr str;
            default = "@error401";
          };
          requestLocation = mkOption {
            type = str;
            default = "/validate";
          };
          requestDirective = mkOption {
            type = lines;
            default = ''
              auth_request ${cfg.auth.requestLocation};
            '';
          };
          variables = mkOption {
            type = attrsOf str;
            default = {
              auth_resp_x_vouch_user = "X-Vouch-User";
              auth_resp_jwt = "X-Vouch-Token";
              auth_resp_err = "X-Vouch-Error";
              auth_resp_success = "X-Vouch-Success";
              auth_resp_redirect = "X-Vouch-Requested-URI";
            };
          };
        };
      };
    };
    config = {
      vouch.auth = {
        lua = {
          accessLogic = mkOptionDefault (mkAfter ''
            if ngx.ctx.auth_res ~= nil and ngx.ctx.auth_res.status == ngx.HTTP_UNAUTHORIZED then
              local vouch_url = ngx.var["vouch_url"] or "${vouch.url}"
              local query_args = ngx.encode_args {
                url = string.format("%s://%s%s", ngx.var.x_scheme, ngx.var.x_forwarded_host, ngx.var.request_uri),
                ["X-Vouch-Token"] = ngx.ctx.auth_res.header["X-Vouch-Token"] or "",
                error = ngx.ctx.auth_res.header["X-Vouch-Error"] or "",
                -- ["vouch-failcount"] is now a session variable and shouldn't be needed anymore
              }

              return ngx.redirect(string.format("%s/login?%s", vouch_url, query_args), ngx.HTTP_MOVED_TEMPORARILY)
            end
            if ngx.ctx.auth_res ~= nil and ngx.ctx.auth_res.status == ngx.HTTP_FORBIDDEN or ngx.ctx.auth_res.status == ngx.HTTP_UNAUTHORIZED then
              return ngx.exit(ngx.ctx.auth_res.status)
            end

            if ngx.ctx.auth_res ~= nil and ngx.ctx.auth_res.status ~= ngx.HTTP_OK then
              return ngx.exit(ngx.HTTP_INTERNAL_SERVER_ERROR)
            end
          '');
          accessVariables = mkMerge (mapAttrsToList (authVar: header: mkOptionDefault
            ''ngx.var["${authVar}"] = ngx.ctx.auth_res.header["${header}"] or ""''
          ) cfg.auth.variables);
        };
        errorLocation = mkIf cfg.auth.lua.enable (mkAlmostOptionDefault null);
        requestDirective = mkIf cfg.auth.lua.enable (mkAlmostOptionDefault "");
      };
      lua = mkIf (cfg.requireAuth && cfg.auth.lua.enable) {
        access.block = mkMerge [
          (mkBefore cfg.auth.lua.accessRequest)
          (mkBefore cfg.auth.lua.accessVariables)
          (mkBefore cfg.auth.lua.accessLogic)
        ];
      };
      extraConfig = let
        localVouchUrl = ''
          if ($x_forwarded_host ~ "\.local\.${networking.domain}$") {
            set $vouch_url ${vouch.localUrl};
          }
        '';
        tailVouchUrl = ''
          if ($x_forwarded_host ~ "\.tail\.${networking.domain}$") {
            set $vouch_url $x_scheme://${vouch.tailDomain};
          }
        '';
        setVouchUrl = [
          (mkBefore ''
            set $vouch_url ${vouch.url};
          '')
          (mkIf cfg.localSso.enable localVouchUrl)
          (mkIf (cfg.localSso.enable && tailscale.enable) tailVouchUrl)
        ];
      in mkIf cfg.enable (mkMerge (
        [
          (mkIf (cfg.requireAuth) (mkBefore cfg.auth.requestDirective))
          (mkIf (cfg.auth.errorLocation != null) "error_page 401 = ${cfg.auth.errorLocation};")
        ] ++ setVouchUrl
        ++ mapAttrsToList (authVar: header: mkIf (!cfg.auth.lua.enable) (
          mkBefore "auth_request_set \$${authVar} ${mkUpstreamVar header};"
        )) cfg.auth.variables
      ));
      proxied.xvars.enable = mkIf cfg.enable true;
      locations = mkIf cfg.enable {
        "/" = mkIf cfg.requireAuth {
          vouch.requireAuth = mkAlmostOptionDefault true;
        };
        ${cfg.auth.errorLocation} = mkIf (cfg.auth.errorLocation != null) {
          proxied.xvars.enable = true;
          extraConfig = ''
            return 302 $vouch_url/login?url=$x_scheme://$x_forwarded_host$request_uri&X-Vouch-Token=$auth_resp_jwt&error=$auth_resp_err;
          '';
        };
        ${cfg.auth.requestLocation} = { config, ... }: {
          proxyPass = "${vouch.proxyOrigin}/validate";
          proxy.headers.enableRecommended = false;
          proxied.rewriteReferer = false;
          extraConfig = let
            # nginx-proxied vouch must use X-Forwarded-Host, but vanilla vouch requires Host
            vouchProxyHost = if vouch.doubleProxy.enable
              then (if cfg.localSso.enable then vouch.doubleProxy.localServerName else vouch.doubleProxy.serverName)
              else "$x_forwarded_host";
          in ''
            proxy_set_header Host ${vouchProxyHost};
            proxy_set_header X-Forwarded-Host $x_forwarded_host;
            proxy_set_header Referer $x_referer;
            proxy_set_header X-Forwarded-Proto $x_scheme;
            proxy_pass_request_body off;
            proxy_set_header Content-Length "";
          '';
        };
      };
    };
  };
in {
  options = with lib.types; {
    services.nginx = {
      vouch = {
        enable = mkEnableOption "vouch auth proxy";
        enableLocal = mkEnableOption "use local vouch instance" // {
          default = true;
        };
        localSso = {
          enable = mkEnableOption "lan-local auth" // {
            default = true;
          };
        };
        proxyOrigin = mkOption {
          type = str;
          default = "https://login.local.${networking.domain}";
        };
        doubleProxy = {
          enable = mkOption {
            type = bool;
            default = true;
          };
          serverName = mkOption {
            type = str;
            default = "@vouch_internal";
          };
          localServerName = mkOption {
            type = str;
            default = "@vouch_internal_local";
          };
        };
        authUrl = mkOption {
          type = str;
          default = "https://sso.${networking.domain}/realms/${networking.domain}";
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
      };
      virtualHosts = mkOption {
        type = attrsOf (submodule hostModule);
      };
    };
  };
  config.services.nginx = {
    vouch = mkMerge [
      {
        proxyOrigin = mkIf (tailscale.enable && !vouch-proxy.enable) (
          mkAlmostOptionDefault "http://login.tail.${networking.domain}"
        );
      }
      (mkIf (vouch.enableLocal && vouch-proxy.enable) {
        proxyOrigin = let
          inherit (vouch-proxy.settings.vouch) listen port;
          host =
            if listen == "0.0.0.0" || listen == "[::]"
            then "localhost"
            else listen;
        in
          mkAlmostOptionDefault "http://${host}:${toString port}";
        authUrl = mkAlmostOptionDefault vouch-proxy.authUrl;
        url = mkAlmostOptionDefault vouch-proxy.url;
        doubleProxy.enable = mkAlmostOptionDefault false;
      })
    ];
  };
}
