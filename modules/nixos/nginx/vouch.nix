{
  config,
  system,
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkAfter mkOptionDefault mkDefault;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.strings) toLower replaceStrings removePrefix;
  inherit (config) networking;
  inherit (config.services) vouch-proxy nginx tailscale;
  inherit (nginx) vouch;
  locationModule = {
    config,
    virtualHost,
    xvars,
    ...
  }: {
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
      enableVouchTail = enableVouchLocal && tailscale.enable && false;
      allowOrigin = url: "add_header Access-Control-Allow-Origin ${url};";
    in
      mkIf config.vouch.requireAuth {
        lua = mkIf virtualHost.vouch.auth.lua.enable {
          access.block = mkMerge [
            (mkBefore virtualHost.vouch.auth.lua.accessRequest)
            (mkBefore virtualHost.vouch.auth.lua.accessVariables)
            (mkBefore virtualHost.vouch.auth.lua.accessLogic)
          ];
        };
        xvars.enable = mkIf (enableVouchTail || virtualHost.vouch.auth.lua.enable) true;
        proxy.headers.set.X-Vouch-User = mkOptionDefault "$auth_resp_x_vouch_user";
        extraConfig = assert virtualHost.vouch.enable;
          mkMerge [
            (mkIf (!virtualHost.vouch.requireAuth) virtualHost.vouch.auth.requestDirective)
            (allowOrigin vouch.url)
            (allowOrigin vouch.authUrl)
            (mkIf enableVouchLocal (allowOrigin vouch.localUrl))
            (mkIf enableVouchLocal (allowOrigin "sso.local.${networking.domain}"))
            (mkIf enableVouchTail (allowOrigin "${xvars.get.scheme}://${vouch.tailDomain}"))
          ];
      };
  };
  hostModule = {
    config,
    xvars,
    ...
  }: let
    cfg = config.vouch;
    mkHeaderVar = header: toLower (replaceStrings ["-"] ["_"] header);
    mkUpstreamVar = header: "\$upstream_http_${mkHeaderVar header}";
  in {
    options = with lib.types; {
      locations = mkOption {
        type = attrsOf (submodule locationModule);
      };
      vouch = {
        enable = mkEnableOption "vouch auth proxy";
        localSso.enable =
          mkEnableOption "lan-local vouch"
          // {
            default = vouch.localSso.enable && config.local.enable;
          };
        requireAuth =
          mkEnableOption "require auth to access this host"
          // {
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
                url = string.format("%s://%s%s", ngx.var.${removePrefix "$" xvars.get.scheme}, ngx.var.${removePrefix "$" xvars.get.host}, ngx.var.request_uri),
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
          accessVariables = mkMerge (mapAttrsToList (
              authVar: header:
                mkOptionDefault
                ''ngx.var["${authVar}"] = ngx.ctx.auth_res.header["${header}"] or ""''
            )
            cfg.auth.variables);
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
          if (${xvars.get.host} ~ "\.local\.${networking.domain}$") {
            set $vouch_url ${vouch.localUrl};
          }
        '';
        tailVouchUrl = ''
          if (${xvars.get.host} ~ "\.tail\.${networking.domain}$") {
            set $vouch_url ${xvars.get.scheme}://${vouch.tailDomain};
          }
        '';
        setVouchUrl = [
          (mkBefore ''
            set $vouch_url ${vouch.url};
          '')
          (mkIf cfg.localSso.enable localVouchUrl)
          (mkIf (cfg.localSso.enable && tailscale.enable) tailVouchUrl)
        ];
      in
        mkIf cfg.enable (mkMerge (
          [
            (mkIf (cfg.requireAuth) (mkBefore cfg.auth.requestDirective))
            (mkIf (cfg.auth.errorLocation != null) "error_page 401 = ${cfg.auth.errorLocation};")
          ]
          ++ setVouchUrl
          ++ mapAttrsToList (authVar: header:
            mkIf (!cfg.auth.lua.enable) (
              mkBefore "auth_request_set \$${authVar} ${mkUpstreamVar header};"
            ))
          cfg.auth.variables
        ));
      xvars.enable = mkIf cfg.enable true;
      locations = mkIf cfg.enable {
        "/" = mkIf cfg.requireAuth {
          vouch.requireAuth = mkAlmostOptionDefault true;
        };
        ${cfg.auth.errorLocation} = mkIf (cfg.auth.errorLocation != null) {
          xvars.enable = true;
          extraConfig = ''
            return 302 $vouch_url/login?url=${xvars.get.scheme}://${xvars.get.host}$request_uri&X-Vouch-Token=$auth_resp_jwt&error=$auth_resp_err;
          '';
        };
        ${cfg.auth.requestLocation} = {
          config,
          xvars,
          ...
        }: {
          proxy = {
            enable = true;
            inheritServerDefaults = false;
            upstream = mkDefault (
              if vouch.doubleProxy.enable
              then "vouch'proxy"
              else if cfg.localSso.enable
              then "vouch'auth'local"
              else "vouch'auth"
            );
            # nginx-proxied vouch must use X-Forwarded-Host, but vanilla vouch requires Host
            host =
              if config.proxy.upstream == "vouch'proxy"
              then
                (
                  if cfg.localSso.enable
                  then vouch.doubleProxy.localServerName
                  else vouch.doubleProxy.serverName
                )
              else xvars.get.host;
            headers = {
              set.Content-Length = "";
              rewriteReferer.enable = false;
            };
          };
          extraConfig = ''
            proxy_pass_request_body off;
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
        localSso = {
          enable =
            mkEnableOption "lan-local auth"
            // {
              default = true;
            };
        };
        doubleProxy = {
          enable = mkOption {
            type = bool;
            default = false;
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
    upstreams' = let
      localVouch = let
        inherit (vouch-proxy.settings.vouch) listen port;
        host =
          if listen == "0.0.0.0" || listen == "[::]"
          then "localhost"
          else listen;
      in {
        # TODO: accessService.exportedId = "login";
        enable = mkAlmostOptionDefault vouch-proxy.enable;
        port = mkIf vouch-proxy.enable (mkOptionDefault port);
        addr = mkIf vouch-proxy.enable (mkAlmostOptionDefault host);
      };
    in {
      vouch'auth = {
        enable = vouch.enable;
        servers = {
          local = localVouch;
          service = {upstream, ...}: {
            enable = mkIf upstream.servers.local.enable false;
            accessService = {
              name = "vouch-proxy";
              id = "login";
            };
          };
        };
      };
      vouch'auth'local = {
        enable = vouch.enable && vouch.localSso.enable;
        servers = {
          local =
            localVouch
            // {
              enable = mkAlmostOptionDefault false;
            };
          service = {upstream, ...}: {
            enable = mkIf upstream.servers.local.enable false;
            accessService = {
              name = "vouch-proxy";
              id = "login.local";
            };
          };
        };
      };
      vouch'proxy = {
        enable = vouch.enable && vouch.doubleProxy.enable;
        # TODO: need exported hosts options for this to detect the correct host/port/etc
        servers = {
          lan = {upstream, ...}: {
            enable = mkAlmostOptionDefault (!upstream.servers.int.enable);
            addr = mkAlmostOptionDefault "login.local.${networking.domain}";
            port = mkOptionDefault 9080;
            ssl.enable = mkAlmostOptionDefault true;
          };
          int = {upstream, ...}: {
            enable = mkAlmostOptionDefault system.network.networks.int.enable or false;
            addr = mkAlmostOptionDefault "login.int.${networking.domain}";
            port = mkOptionDefault 9080;
          };
          tail = {upstream, ...}: {
            enable = mkAlmostOptionDefault (tailscale.enable && !upstream.servers.lan.enable && !upstream.servers.int.enable);
            addr = mkAlmostOptionDefault "login.tail.${networking.domain}";
            port = mkOptionDefault 9080;
          };
        };
      };
    };
  };
}
