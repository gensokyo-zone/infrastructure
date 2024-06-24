let
  proxyModule = {
    config,
    name,
    options,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkMerge mkAfter mkOptionDefault;
    inherit (lib.strings) optionalString;
    cfg = config.proxy;
  in {
    options = with lib.types; {
      proxy = {
        enable = mkEnableOption "proxy_pass";
        bind = {
          enable = mkEnableOption "proxy_bind";
          transparent = mkEnableOption "proxy_bind transparent";
          address = mkOption {
            type = str;
          };
        };
        url = mkOption {
          type = str;
        };
      };
    };

    config = {
      proxy = {
        bind.address = mkIf cfg.bind.transparent (mkOptionDefault "$remote_addr");
      };
      extraConfig = mkIf cfg.enable (mkMerge [
        (mkIf cfg.bind.enable (mkAfter (
          "proxy_bind ${cfg.bind.address}" + optionalString cfg.bind.transparent " transparent" + ";"
        )))
      ]);
    };
  };
  serverModule = {
    config,
    name,
    options,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (lib.modules) mkIf mkAfter;
    cfg = config.proxy;
  in {
    imports = [proxyModule];

    config = let
      warnProxy = lib.warnIf (!cfg.enable && options.proxy.url.isDefined) "nginx.stream.servers.${name}.proxy.url set without proxy.enable";
    in {
      streamConfig = warnProxy (mkIf cfg.enable (
        mkAfter
        "proxy_pass ${cfg.url};"
      ));
    };
  };
  locationModule = {
    config,
    nixosConfig,
    name,
    virtualHost,
    xvars,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mkJustBefore mkJustAfter mkAlmostOptionDefault mapOptionDefaults coalesce parseUrl;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkMerge mkBefore mkOptionDefault;
    inherit (lib.attrsets) filterAttrs mapAttrsToList;
    inherit (lib.lists) optional;
    inherit (lib.strings) hasPrefix removeSuffix optionalString concatStringsSep;
    inherit (lib.trivial) mapNullable;
    inherit (nixosConfig.services) nginx;
    cfg = config.proxy;
  in {
    imports = [proxyModule];

    options = with lib.types; {
      proxy = {
        enabled = mkOption {
          type = bool;
          readOnly = true;
        };
        inheritServerDefaults = mkOption {
          type = bool;
          default = true;
        };
        path = mkOption {
          type = str;
        };
        host = mkOption {
          type = nullOr str;
        };
        websocket.enable =
          mkEnableOption "websocket proxy"
          // {
            default = cfg.inheritServerDefaults && virtualHost.proxy.websocket.enable;
          };
        parsed = {
          scheme = mkOption {
            type = nullOr str;
          };
          path = mkOption {
            type = nullOr str;
          };
          host = mkOption {
            type = nullOr str;
          };
          port = mkOption {
            type = nullOr int;
          };
        };
        headers = {
          enableRecommended = mkOption {
            type = enum [true false "nixpkgs"];
          };
          rewriteReferer.enable = mkEnableOption "rewrite referer host";
          set = mkOption {
            type = attrsOf (nullOr str);
          };
          hide = mkOption {
            type = attrsOf bool;
            default = {};
          };
        };
        redirect = {
          enable = mkEnableOption "proxy_redirect";
          fromHost = mkOption {
            type = str;
            default = xvars.get.host;
            example = "xvars.get.proxy_host";
          };
          fromScheme = mkOption {
            type = str;
            default = xvars.get.scheme;
            example = "xvars.get.proxy_scheme";
          };
        };
      };
    };
    config = let
      emitHeaders = setHeaders' != {};
      url = parseUrl config.proxyPass;
      upstream = nginx.upstreams'.${cfg.upstream};
      upstreamServer = upstream.servers.${upstream.defaultServerName};
      dynamicUpstream = hasPrefix "$" cfg.upstream;
      hasUpstream = cfg.upstream != null && !dynamicUpstream;
      hasUpstreamServer = upstream.defaultServerName != null;
      recommendedHeaders = {
        Host =
          if cfg.host == null
          then xvars.get.proxy_hostport
          else cfg.host;
        Referer = xvars.get.referer;
        CF-Connecting-IP = xvars.get.remote_addr;
        X-Real-IP = xvars.get.remote_addr;
        X-Forwarded-For = xvars.get.forwarded_for;
        X-Forwarded-Proto = xvars.get.scheme;
        X-Forwarded-Host = xvars.get.host;
        X-Forwarded-Server = xvars.get.forwarded_server;
      };
      schemePort =
        {
          http = 80;
          https = 443;
        }
        .${cfg.parsed.scheme}
        or (throw "unsupported proxy_scheme ${toString cfg.parsed.scheme}");
      upstreamHost = coalesce ([upstream.host] ++ optional hasUpstreamServer upstreamServer.addr);
      port = coalesce [cfg.parsed.port schemePort];
      hostport = cfg.parsed.host + optionalString (port != schemePort) ":${toString port}";
      initProxyVars = let
        initScheme = xvars.init "proxy_scheme" config.xvars.defaults.proxy_scheme;
        initHost = xvars.init "proxy_host" config.xvars.defaults.proxy_host;
        initPort = xvars.init "proxy_port" config.xvars.defaults.proxy_port;
        initHostPort = xvars.init "proxy_hostport" config.xvars.defaults.proxy_hostport;
        initUpstream = ''
          ${initScheme}
          ${initHost}
          ${initPort}
          ${initHostPort}
        '';
        initDynamic = ''
          ${initScheme}
          ${xvars.init "proxy_host" "$proxy_host"}
          if (${xvars.get.proxy_host} = "") {
            ${initHost}
          }
          ${xvars.init "proxy_port" "$proxy_port"}
          if (${xvars.get.proxy_port} = "") {
            ${initPort}
          }

          ${xvars.init "proxy_hostport" "${xvars.get.proxy_host}:${xvars.get.proxy_port}"}
          if (${xvars.get.proxy_port} = ${toString schemePort}) {
            ${xvars.init "proxy_hostport" xvars.get.proxy_host}
          }
          if (${xvars.get.proxy_port} = "") {
            ${xvars.init "proxy_hostport" xvars.get.proxy_host}
          }
        '';
        init =
          if cfg.upstream != null
          then initUpstream
          else initDynamic;
      in
        init;
      hostHeader = coalesce [
        cfg.headers.set.Host or null
        cfg.host
        xvars.get.proxy_hostport
      ];
      rewriteReferer = ''
        if (${xvars.get.referer_host} = $host) {
          ${xvars.init "referer" "${xvars.get.proxy_scheme}://${hostHeader}${xvars.get.referer_path}"}
        }
      '';
      redirect = ''
        proxy_redirect ${cfg.redirect.fromScheme}://${cfg.redirect.fromHost}/ ${xvars.get.scheme}://${xvars.get.host}/;
      '';
      setHeaders' = filterAttrs (_: header: header != null) cfg.headers.set;
      setHeaders = concatStringsSep "\n" (mapAttrsToList (
          name: value: "proxy_set_header ${name} ${xvars.escapeString value};"
        )
        setHeaders');
      hideHeaders = mapAttrsToList (header: hide: mkIf hide "proxy_hide_header ${xvars.escapeString header};") cfg.headers.hide;
    in {
      xvars = {
        enable = mkIf cfg.headers.rewriteReferer.enable true;
        defaults = mkIf cfg.enabled (mapOptionDefaults {
          proxy_scheme = cfg.parsed.scheme;
          proxy_host = cfg.parsed.host;
          proxy_port = toString port;
          proxy_hostport = hostport;
        });
      };
      proxy = {
        enabled = mkOptionDefault (config.proxyPass != null);
        path = mkIf (hasPrefix "/" name) (mkOptionDefault name);
        url = mkIf (cfg.inheritServerDefaults && virtualHost.proxy.url != null) (mkOptionDefault virtualHost.proxy.url);
        headers = {
          enableRecommended = mkOptionDefault (
            if cfg.enable && (!cfg.inheritServerDefaults || virtualHost.proxy.headers.enableRecommended != false)
            then true
            else if cfg.inheritServerDefaults
            then virtualHost.proxy.headers.enableRecommended
            else if nginx.recommendedProxySettings
            then "nixpkgs"
            else false
          );
          set = mkMerge [
            (mkOptionDefault {})
            (mkIf (cfg.headers.enableRecommended == true) (mapOptionDefaults recommendedHeaders))
            (mkIf (cfg.host != null) {
              Host = mkIf (cfg.headers.enableRecommended != "nixpkgs") (mkAlmostOptionDefault cfg.host);
            })
            (mkIf cfg.headers.rewriteReferer.enable {
              Referer = mkAlmostOptionDefault xvars.get.referer;
            })
            (mkIf cfg.websocket.enable (mapOptionDefaults {
              Upgrade = "$http_upgrade";
              Connection = "upgrade";
            }))
          ];
        };
        host = mkOptionDefault (
          if cfg.inheritServerDefaults && virtualHost.proxy.host != null
          then virtualHost.proxy.host
          else if cfg.headers.enableRecommended == false
          then null
          else xvars.get.host
        );
        parsed = {
          scheme = mkOptionDefault (
            mapNullable (_: url.scheme) config.proxyPass
          );
          path = mkOptionDefault (
            mapNullable (_: url.path) config.proxyPass
          );
          host = mkOptionDefault (
            if hasUpstream
            then assert url.host == upstream.name; upstreamHost
            else mapNullable (_: url.host) config.proxyPass
          );
          port = mkOptionDefault (
            if hasUpstream && hasUpstreamServer && url.port == null
            then assert url.host == upstream.name; upstreamServer.port
            else mapNullable (_: url.port) config.proxyPass
          );
        };
      };
      proxyPass = mkIf cfg.enable (mkAlmostOptionDefault (removeSuffix "/" cfg.url + cfg.path));
      recommendedProxySettings = mkAlmostOptionDefault (cfg.headers.enableRecommended == "nixpkgs");
      extraConfig = mkIf cfg.enabled (mkMerge ([
          (mkIf virtualHost.xvars.enable (mkJustBefore initProxyVars))
          (mkIf (cfg.headers.rewriteReferer.enable) (mkJustBefore rewriteReferer))
          (mkIf (cfg.redirect.enable) (mkBefore redirect))
          (mkIf emitHeaders (mkJustAfter setHeaders))
          (mkIf cfg.websocket.enable "proxy_cache_bypass $http_upgrade;")
        ]
        ++ hideHeaders));
    };
  };
  hostModule = {
    config,
    nixosConfig,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mapOptionDefaults mapAlmostOptionDefaults;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkOptionDefault;
    inherit (lib.attrsets) attrValues;
    inherit (lib.lists) any;
    inherit (nixosConfig.services) nginx;
    cfg = config.proxy;
    anyLocations = f: any (loc: loc.enable && f loc) (attrValues config.locations);
  in {
    options = with lib.types; {
      proxy = {
        host = mkOption {
          type = nullOr str;
          default = null;
        };
        url = mkOption {
          type = nullOr str;
          default = null;
        };
        copyFromVhost = mkOption {
          type = nullOr str;
          default = null;
        };
        websocket.enable = mkEnableOption "websocket proxy";
        headers.enableRecommended = mkOption {
          type = enum [true false "nixpkgs"];
          default =
            if nginx.recommendedProxySettings
            then "nixpkgs"
            else false;
        };
      };
      locations = mkOption {
        type = attrsOf (submoduleWith {
          modules = [locationModule];
          shorthandOnlyDefinesConfig = true;
        });
      };
    };
    config = let
      needsReferer = loc: loc.proxy.enabled && loc.proxy.headers.rewriteReferer.enable;
      confCopy = let
        proxyHost = nginx.virtualHosts.${cfg.copyFromVhost};
      in
        mapAlmostOptionDefaults {
          inherit (proxyHost.proxy) host url upstream;
        }
        // {
          websocket = mapAlmostOptionDefaults {
            inherit (proxyHost.proxy.websocket) enable;
          };
          headers = mapAlmostOptionDefaults {
            inherit (proxyHost.proxy.headers) enableRecommended;
          };
        };
    in {
      xvars = {
        parseReferer = mkIf (anyLocations needsReferer) true;
        defaults = mkIf (anyLocations (loc: loc.proxy.enabled)) (mkOptionDefault (mapOptionDefaults rec {
          proxy_scheme = null;
          proxy_host = "$proxy_host";
          proxy_port = "$proxy_port";
          proxy_hostport = "${proxy_host}:${proxy_port}";
        }));
      };
      proxy = mkIf (cfg.copyFromVhost != null) confCopy;
    };
  };
in
  {lib, ...}: let
    inherit (lib.options) mkOption;
  in {
    options.services.nginx = with lib.types; {
      virtualHosts = mkOption {
        type = attrsOf (submodule [hostModule]);
      };
      stream.servers = mkOption {
        type = attrsOf (submoduleWith {
          modules = [serverModule];
          shorthandOnlyDefinesConfig = false;
        });
      };
    };
  }
