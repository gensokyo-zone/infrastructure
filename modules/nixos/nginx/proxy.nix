let
  locationModule = { config, name, virtualHost, xvars, gensokyo-zone, lib, ... }: let
    inherit (gensokyo-zone.lib) mkJustBefore mkJustAfter mkAlmostOptionDefault mapOptionDefaults coalesce parseUrl;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkMerge mkBefore mkOptionDefault;
    inherit (lib.attrsets) filterAttrs mapAttrsToList;
    inherit (lib.strings) hasPrefix removeSuffix concatStringsSep;
    inherit (lib.trivial) mapNullable;
    cfg = config.proxy;
  in {
    options = with lib.types; {
      proxy = {
        enable = mkEnableOption "proxy";
        enabled = mkOption {
          type = bool;
          readOnly = true;
        };
        url = mkOption {
          type = str;
        };
        path = mkOption {
          type = str;
        };
        host = mkOption {
          type = nullOr str;
        };
        websocket.enable = mkEnableOption "websocket proxy" // {
          default = virtualHost.proxy.websocket.enable;
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
          hostport = mkOption {
            type = nullOr str;
          };
          port = mkOption {
            type = nullOr int;
          };
        };
        headers = {
          enableRecommended = mkOption {
            type = enum [ true false "nixpkgs" ];
          };
          rewriteReferer.enable = mkEnableOption "rewrite referer host";
          set = mkOption {
            type = attrsOf (nullOr str);
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
      emitHeaders = setHeaders' != { };
      url = parseUrl config.proxyPass;
      recommendedHeaders = {
        Host = if cfg.host == null then xvars.get.proxy_host else cfg.host;
        Referer = xvars.get.referer;
        X-Real-IP = xvars.get.remote_addr;
        X-Forwarded-For = xvars.get.forwarded_for;
        X-Forwarded-Proto = xvars.get.scheme;
        X-Forwarded-Host = xvars.get.host;
        X-Forwarded-Server = xvars.get.forwarded_server;
      };
      initProxyVars = ''
        ${xvars.init "proxy_scheme" cfg.parsed.scheme}
        ${xvars.init "proxy_host" "$proxy_host"}
        if (${xvars.get.proxy_host} = "") {
          ${xvars.init "proxy_host" cfg.parsed.hostport}
        }
      '';
      hostHeader = coalesce [
        cfg.headers.set.Host or null
        cfg.host
        xvars.get.proxy_host
      ];
      rewriteReferer = ''
        set $x_set_referer ${xvars.get.referer};
        if (${xvars.get.referer_host} = $host) {
          set $x_set_referer ${config.proxy.parsed.scheme}://${hostHeader}${xvars.get.referer_path};
        }
      '';
      redirect = ''
        proxy_redirect ${cfg.redirect.fromScheme}://${cfg.redirect.fromHost}/ ${xvars.get.scheme}://${xvars.get.host}/;
      '';
      setHeaders' = filterAttrs (_: header: header != null) cfg.headers.set;
      setHeaders = concatStringsSep "\n" (mapAttrsToList (
        name: value: "proxy_set_header ${name} ${xvars.escapeString value};"
      ) setHeaders');
    in {
      proxy = {
        enabled = mkOptionDefault (config.proxyPass != null);
        path = mkIf (hasPrefix "/" name) (mkOptionDefault name);
        url = mkIf (virtualHost.proxy.url != null) (mkOptionDefault virtualHost.proxy.url);
        headers = {
          enableRecommended = mkOptionDefault (
            if cfg.enable && virtualHost.proxy.headers.enableRecommended != false then true
            else virtualHost.proxy.headers.enableRecommended
          );
          set = mkMerge [
            (mkOptionDefault { })
            (mkIf (cfg.headers.enableRecommended == true) (mapOptionDefaults recommendedHeaders))
            (mkIf (cfg.host != null) {
              Host = mkIf (cfg.headers.enableRecommended != "nixpkgs") (mkAlmostOptionDefault cfg.host);
            })
            (mkIf cfg.headers.rewriteReferer.enable {
              Referer = mkAlmostOptionDefault "$x_set_referer";
            })
            (mkIf cfg.websocket.enable (mapOptionDefaults {
              Upgrade = "$http_upgrade";
              Connection = "upgrade";
            }))
          ];
        };
        host = mkOptionDefault (
          if virtualHost.proxy.host != null then virtualHost.proxy.host
          else if cfg.headers.enableRecommended == false then null
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
            mapNullable (_: url.host) config.proxyPass
          );
          hostport = mkOptionDefault (
            mapNullable (_: url.hostport) config.proxyPass
          );
          port = mkOptionDefault (
            mapNullable (_: url.port) config.proxyPass
          );
        };
      };
      proxyPass = mkIf cfg.enable (mkAlmostOptionDefault (removeSuffix "/" cfg.url + cfg.path));
      recommendedProxySettings = mkAlmostOptionDefault (cfg.headers.enableRecommended == "nixpkgs");
      extraConfig = mkMerge [
        (mkIf (cfg.enabled && virtualHost.xvars.enable) (mkJustBefore initProxyVars))
        (mkIf (cfg.enabled && cfg.headers.rewriteReferer.enable) (mkJustBefore rewriteReferer))
        (mkIf (cfg.enabled && cfg.redirect.enable) (mkBefore redirect))
        (mkIf (cfg.enabled && emitHeaders) (mkJustAfter setHeaders))
      ];
    };
  };
  hostModule = { config, nixosConfig, lib, ... }: let
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf;
    inherit (lib.attrsets) attrValues;
    inherit (lib.lists) any;
    inherit (nixosConfig.services) nginx;
    cfg = config.proxy;
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
        websocket.enable = mkEnableOption "websocket proxy";
        headers.enableRecommended = mkOption {
          type = enum [ true false "nixpkgs" ];
          default = if nginx.recommendedProxySettings then "nixpkgs" else false;
        };
      };
      locations = mkOption {
        type = attrsOf (submoduleWith {
          modules = [ locationModule ];
          shorthandOnlyDefinesConfig = true;
        });
      };
    };
    config = let
      needsReferer = loc: loc.proxy.enabled && loc.proxy.headers.rewriteReferer.enable;
    in {
      xvars.parseReferer = mkIf (any needsReferer (attrValues config.locations)) true;
    };
  };
in {
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
in {
  options = with lib.types; {
    services.nginx.virtualHosts = mkOption {
      type = attrsOf (submodule [hostModule]);
    };
  };
}
