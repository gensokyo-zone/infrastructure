{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkAfter mkOrder mkDefault mkOptionDefault mkOverride;
  inherit (lib.strings) optionalString splitString match;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) length head /*optional*/ any;
  inherit (lib.trivial) mapNullable;
  #inherit (config) networking;
  inherit (config.services) nginx;
  mkAlmostAfter = mkOrder 1250;
  mkAlmostOptionDefault = mkOverride 1250;
  schemeForUrl = url: let
    parts = splitString ":" url;
  in if length parts == 1 then null else head parts;
  pathForUrl = url: let
    parts = match ''[^:]+://[^/]+(.*)'' url;
  in if parts == null then null else head parts;
  hostForUrl = url: let
    parts = match ''[^:]+://([^/]+).*'' url;
  in if parts == null then null else head parts;
  xHeadersDefaults = ''
    set $x_scheme $scheme;
    set $x_forwarded_for $remote_addr;
    set $x_remote_addr $remote_addr;
    set $x_forwarded_host $host;
    set $x_forwarded_server $host;
    set $x_host $host;
    set $x_referer $http_referer;
    set $x_proxy_host $x_host;
  '';
  xHeadersProxied = ''
    set $x_forwarded_for $proxy_add_x_forwarded_for;
    if ($http_x_forwarded_proto) {
      set $x_scheme $http_x_forwarded_proto;
    }
    if ($http_x_real_ip) {
      set $x_remote_addr $http_x_real_ip;
    }
    if ($http_x_forwarded_host) {
      set $x_forwarded_host $http_x_forwarded_host;
    }
    if ($http_x_forwarded_server) {
      set $x_forwarded_server $http_x_forwarded_server;
    }
    if ($x_referer ~ "^https?://([^/]*)/(.*)$") {
      set $x_referer_host $1;
      set $x_referer_path $2;
    }
  '';
  locationModule = { config, virtualHost, ... }: let
    cfg = config.proxied;
  in {
    options = with lib.types; {
      proxied = {
        enable = mkOption {
          type = enum [ false true "cloudflared" ];
          default = false;
        };
        enabled = mkOption {
          type = bool;
          readOnly = true;
        };
        xvars.enable = mkEnableOption "$x_variables";
        redirectScheme = mkEnableOption "redirect to X-Forwarded-Proto" // {
          default = cfg.enabled;
        };
        rewriteReferer = mkEnableOption "rewrite Referer header" // {
          default = cfg.enabled;
        };
      };
      proxy = {
        enabled = mkOption {
          type = bool;
          readOnly = true;
        };
        scheme = mkOption {
          type = nullOr str;
        };
        path = mkOption {
          type = nullOr str;
        };
        host = mkOption {
          type = nullOr str;
        };
        headers.enableRecommended = mkOption {
          type = enum [ true false "nixpkgs" ];
        };
      };
    };
    config = let
      emitVars = cfg.enabled && !virtualHost.proxied.enabled;
      emitRedirectScheme = config.proxy.enabled && cfg.redirectScheme;
      emitRefererRewrite = config.proxy.enabled && cfg.rewriteReferer;
      emitHeaders = config.proxy.enabled && config.proxy.headers.enableRecommended == true;
    in {
      proxied = {
        enabled = mkOptionDefault (virtualHost.proxied.enabled || cfg.enable != false);
        xvars.enable = mkIf (cfg.enabled || emitRedirectScheme || emitHeaders) true;
      };
      proxy = {
        enabled = mkOptionDefault (config.proxyPass != null);
        headers.enableRecommended = mkOptionDefault (
          if !virtualHost.recommendedProxySettings then false
          else if cfg.enabled then true
          else "nixpkgs"
        );
        scheme = mkOptionDefault (
          mapNullable schemeForUrl config.proxyPass
        );
        path = mkOptionDefault (
          mapNullable pathForUrl config.proxyPass
        );
        host = mkOptionDefault (
          mapNullable hostForUrl config.proxyPass
        );
      };
      recommendedProxySettings = mkMerge [
        (mkAlmostOptionDefault (config.proxy.headers.enableRecommended == "nixpkgs"))
      ];
      extraConfig = mkMerge [
        (mkIf emitVars (
          mkBefore xHeadersProxied
        ))
        (mkIf emitRedirectScheme ''
          proxy_redirect ${config.proxy.scheme}://$host/ $x_scheme://$host/;
        '')
        (mkIf emitRefererRewrite ''
          if ($x_referer_host = $host) {
            set $x_referer "${config.proxy.scheme}://${config.proxy.host}/$x_referer_path";
          }
        '')
        (mkIf emitHeaders (mkAlmostAfter ''
          if ($x_proxy_host = "") {
            set $x_proxy_host $proxy_host;
          }
          if ($x_proxy_host = "") {
            set $x_proxy_host ${config.proxy.host};
          }
          proxy_set_header Host $x_proxy_host;
          proxy_set_header Referer $x_referer;
          proxy_set_header X-Real-IP $x_remote_addr;
          proxy_set_header X-Forwarded-For $x_forwarded_for;
          proxy_set_header X-Forwarded-Proto $x_scheme;
          proxy_set_header X-Forwarded-Host $x_forwarded_host;
          proxy_set_header X-Forwarded-Server $x_forwarded_server;
        ''))
      ];
    };
  };
  hostModule = { config, ... }: let
    cfg = config.proxied;
  in {
    options = with lib.types; {
      proxied = {
        enable = mkOption {
          type = enum [ false true "cloudflared" ];
          default = false;
        };
        enabled = mkOption {
          type = bool;
          default = cfg.enable != false;
        };
        xvars.enable = mkEnableOption "$x_variables" // {
          default = cfg.enabled;
        };
      };
      recommendedProxySettings = mkOption {
        type = bool;
        default = nginx.recommendedProxySettings;
      };
      locations = mkOption {
        type = attrsOf (submoduleWith {
          modules = [ locationModule ];
          shorthandOnlyDefinesConfig = true;
        });
      };
    };

    config = {
      proxied = {
        xvars.enable = mkIf (any (loc: loc.proxied.xvars.enable) (attrValues config.locations)) true;
      };
      local.denyGlobal = mkIf (cfg.enable == "cloudflared") (mkDefault true);
      extraConfig = mkIf cfg.xvars.enable (mkBefore ''
        ${xHeadersDefaults}
        ${optionalString cfg.enabled xHeadersProxied}
      '');
    };
  };
in {
  options = with lib.types; {
    services.nginx.virtualHosts = mkOption {
      type = attrsOf (submoduleWith {
        modules = [ hostModule ];
        shorthandOnlyDefinesConfig = true;
      });
    };
  };
}
