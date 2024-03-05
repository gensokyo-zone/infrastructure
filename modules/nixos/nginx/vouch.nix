{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkDefault;
  inherit (config) networking;
  inherit (config.services) vouch-proxy nginx tailscale;
  inherit (nginx) vouch;
  locationModule = {config, virtualHost, ...}: {
    options.vouch = with lib.types; {
      requireAuth = mkEnableOption "require auth to access this location";
    };
    config = mkIf config.vouch.requireAuth {
      proxied.xvars.enable = true;
      extraConfig = assert virtualHost.vouch.enable; mkMerge [
        ''
          add_header Access-Control-Allow-Origin ${vouch.url};
          add_header Access-Control-Allow-Origin ${vouch.authUrl};
        ''
        (mkIf (vouch.localSso.enable && config.local.enable) ''
          add_header Access-Control-Allow-Origin ${vouch.localUrl};
        '')
        (mkIf (vouch.localSso.enable && config.local.enable && tailscale.enable) ''
          add_header Access-Control-Allow-Origin $x_scheme://${vouch.tailDomain};
        '')
        ''
          proxy_set_header X-Vouch-User $auth_resp_x_vouch_user;
        ''
      ];
    };
  };
  hostModule = {config, ...}: let
    cfg = config.vouch;
  in {
    options = with lib.types; {
      locations = mkOption {
        type = attrsOf (submodule locationModule);
      };
      vouch = {
        enable = mkEnableOption "vouch auth proxy";
        requireAuth = mkEnableOption "require auth to access this host" // {
          default = true;
        };
        errorLocation = mkOption {
          type = str;
          default = "@error401";
        };
        authRequestLocation = mkOption {
          type = str;
          default = "/validate";
        };
        authRequestDirective = mkOption {
          type = lines;
          default = ''
            auth_request ${cfg.authRequestLocation};
          '';
        };
      };
    };
    config = {
      extraConfig = mkIf (cfg.enable && cfg.requireAuth) ''
        ${cfg.authRequestDirective}
        error_page 401 = ${cfg.errorLocation};
      '';
      locations = mkIf cfg.enable {
        "/" = mkIf cfg.requireAuth {
          vouch.requireAuth = true;
        };
        ${cfg.errorLocation} = {
          proxied.xvars.enable = true;
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
          in
            mkMerge [
              (mkBefore ''
                set $vouch_url ${vouch.url};
              '')
              (mkIf (vouch.localSso.enable && config.local.enable or false) localVouchUrl)
              (mkIf (vouch.localSso.enable && config.local.enable or false && tailscale.enable) tailVouchUrl)
              ''
                return 302 $vouch_url/login?url=$x_scheme://$x_forwarded_host$request_uri&vouch-failcount=$auth_resp_failcount&X-Vouch-Token=$auth_resp_jwt&error=$auth_resp_err;
              ''
            ];
        };
        ${cfg.authRequestLocation} = {
          proxyPass = "${vouch.proxyOrigin}/validate";
          proxy.headers.enableRecommended = true;
          extraConfig = let
            # nginx-proxied vouch must use X-Forwarded-Host, but vanilla vouch requires Host
            vouchProxyHost = if vouch.doubleProxy
              then "''"
              else "$x_forwarded_host";
          in ''
            set $x_proxy_host ${vouchProxyHost};
            proxy_pass_request_body off;
            proxy_set_header Content-Length "";
            auth_request_set $auth_resp_x_vouch_user $upstream_http_x_vouch_user;
            auth_request_set $auth_resp_jwt $upstream_http_x_vouch_jwt;
            auth_request_set $auth_resp_err $upstream_http_x_vouch_err;
            auth_request_set $auth_resp_failcount $upstream_http_x_vouch_failcount;
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
          # NOTE: this won't work without multiple vouch-proxy instances with different auth urls...
          enable = mkEnableOption "lan-local auth";
        };
        proxyOrigin = mkOption {
          type = str;
          default = "https://login.local.${networking.domain}";
        };
        doubleProxy = mkOption {
          type = bool;
          default = true;
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
          mkDefault "http://login.tail.${networking.domain}"
        );
      }
      (mkIf vouch-proxy.enable {
        proxyOrigin = let
          inherit (vouch-proxy.settings.vouch) listen port;
          host =
            if listen == "0.0.0.0" || listen == "[::]"
            then "localhost"
            else listen;
        in
          mkDefault "http://${host}:${toString port}";
        authUrl = mkDefault vouch-proxy.authUrl;
        url = mkDefault vouch-proxy.url;
        doubleProxy = mkDefault false;
      })
    ];
  };
}
