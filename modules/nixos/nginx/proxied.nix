let
  xInit = true;
  xCloudflared = {virtualHost}: let
    host =
      if virtualHost.proxied.cloudflared.host == virtualHost.serverName
      then "$server_name"
      else "'${virtualHost.proxied.cloudflared.host}'";
  in ''
    set $proxied_cf on;
    set $proxied_host_cf ${host};
  '';
  xHeadersProxied = {xvars}: ''
    ${xvars.init "forwarded_for" "$proxy_add_x_forwarded_for"}
    if ($http_x_forwarded_proto) {
      ${xvars.init "scheme" "$http_x_forwarded_proto"}
    }
    ${xvars.init "https" ""}
    if (${xvars.get.scheme} = https) {
      ${xvars.init "https" "on"}
    }
    if ($http_x_real_ip) {
      ${xvars.init "remote_addr" "$http_x_real_ip"}
    }
    if ($http_cf_connecting_ip) {
      ${xvars.init "remote_addr" "$http_cf_connecting_ip"}
    }
    if ($http_x_forwarded_host) {
      ${xvars.init "host" "$http_x_forwarded_host"}
    }
    if ($http_x_forwarded_server) {
      ${xvars.init "forwarded_server" "$http_x_forwarded_server"}
    }
  '';
  xDefaults = {cfg}: let
    defaults = {
      ${toString true} = {
        remote_addr = "$proxied_remote_addr_x";
        host = "$proxied_host_x";
        forwarded_server = "$proxied_forwarded_server_x";
      };
      "cloudflared" = {
        remote_addr = "$proxied_remote_addr_cf";
        host = "$proxied_host_cf";
      };
    };
  in
    {
      forwarded_for = "$proxy_add_x_forwarded_for";
      scheme = "$proxied_scheme";
      https = "$proxied_https";
    }
    // defaults.${cfg.enable};
  locationModule = {
    config,
    virtualHost,
    xvars,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mkJustBefore mkAlmostOptionDefault mapAlmostOptionDefaults;
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkIf mkMerge mkOptionDefault;
    cfg = config.proxied;
  in {
    options = with lib.types; {
      proxied = {
        enable = mkOption {
          type = enum [false true "cloudflared"];
          default = false;
        };
        enabled = mkOption {
          type = bool;
          readOnly = true;
        };
      };
    };
    config = let
      emitVars = cfg.enabled && !virtualHost.proxied.enabled;
    in {
      proxied = {
        enabled = mkOptionDefault (virtualHost.proxied.enabled || cfg.enable != false);
      };
      proxy = {
        headers = {
          enableRecommended = mkIf cfg.enabled (mkAlmostOptionDefault true);
          rewriteReferer.enable = mkIf cfg.enabled (mkAlmostOptionDefault true);
        };
        redirect = mkIf cfg.enabled {
          enable = mkAlmostOptionDefault true;
          fromScheme = mkAlmostOptionDefault xvars.get.proxy_scheme;
        };
      };
      fastcgi = {
        passHeaders = {
          X-Accel-Buffering = mkOptionDefault true;
        };
      };
      xvars = mkIf cfg.enabled {
        enable = mkIf xInit true;
        defaults = mkIf (!xInit && cfg.enable != virtualHost.proxied.enable) (mapAlmostOptionDefaults (xDefaults {inherit cfg;}));
      };
      extraConfig = mkMerge [
        (mkIf (cfg.enable == "cloudflared" && virtualHost.proxied.enable != "cloudflared") (
          mkJustBefore (xCloudflared {inherit virtualHost;})
        ))
        (mkIf (xInit && emitVars) (
          mkJustBefore (xHeadersProxied {inherit xvars;})
        ))
      ];
    };
  };
  hostModule = {
    config,
    nixosConfig,
    xvars,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mkAlmostOptionDefault mapAlmostOptionDefaults orderJustBefore unmerged;
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkIf mkMerge mkOrder mkDefault;
    inherit (nixosConfig.services) nginx;
    cfg = config.proxied;
  in {
    options = with lib.types; {
      proxied = {
        enable = mkOption {
          type = enum [false true "cloudflared"];
          default = false;
        };
        enabled = mkOption {
          type = bool;
          default = cfg.enable != false;
        };
        cloudflared = {
          host = mkOption {
            type = str;
            default = config.serverName;
          };
          originHost = mkOption {
            type = str;
            default = config.serverName;
          };
          ingressSettings = mkOption {
            type = unmerged.types.attrs;
          };
          getIngress = mkOption {
            type = functionTo unspecified;
          };
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
      listenProxied = cfg.enabled;
    in {
      proxied = {
        cloudflared = let
          listen = config.listen'.proxied;
          scheme =
            if listen.ssl
            then "https"
            else "http";
        in
          mkIf (cfg.enable == "cloudflared") {
            ingressSettings.${cfg.cloudflared.host} = {
              service = "${scheme}://localhost:${toString listen.port}";
              originRequest = let
                noTLSVerify =
                  if scheme == "https"
                  then "noTLSVerify"
                  else null;
                httpHostHeader =
                  if cfg.cloudflared.host != cfg.cloudflared.originHost
                  then "httpHostHeader"
                  else null;
              in {
                ${noTLSVerify} = true;
                ${httpHostHeader} = cfg.cloudflared.originHost;
              };
            };
            getIngress = {}: unmerged.mergeAttrs cfg.cloudflared.ingressSettings;
          };
      };
      xvars = mkIf cfg.enabled {
        enable = mkIf xInit true;
        defaults = mkIf (!xInit) (mapAlmostOptionDefaults (xDefaults {inherit cfg;}));
      };
      local.denyGlobal = mkIf listenProxied (mkDefault true);
      listen' = mkIf listenProxied {
        proxied = {
          addr = mkAlmostOptionDefault nginx.proxied.listenAddr;
          port = mkAlmostOptionDefault nginx.proxied.listenPort;
        };
      };
      accessLog = mkIf cfg.enabled {
        format = mkDefault (
          if cfg.enable == "cloudflared"
          then "combined_cloudflared"
          else "combined_proxied"
        );
      };
      extraConfig = mkMerge [
        (mkIf (cfg.enable == "cloudflared") (
          mkOrder orderJustBefore (xCloudflared {virtualHost = config;})
        ))
        (mkIf (xInit && cfg.enabled && config.xvars.enable) (
          mkOrder (orderJustBefore + 25) (xHeadersProxied {inherit xvars;})
        ))
      ];
    };
  };
in
  {
    config,
    systemConfig,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf;
    inherit (lib.attrsets) attrValues;
    inherit (lib.lists) any;
    inherit (config.services) nginx;
    cfg = nginx.proxied;
  in {
    options.services.nginx = with lib.types; {
      proxied = {
        enable = mkEnableOption "proxy";
        listenAddr = mkOption {
          type = str;
          default = "[::]";
        };
        listenPort = mkOption {
          type = port;
          default = 9080;
        };
      };
      virtualHosts = mkOption {
        type = attrsOf (submodule [hostModule]);
      };
    };
    config = {
      services.nginx = let
        warnEnable = lib.warnIf (cfg.enable != hasProxiedHosts) "services.nginx.proxied.enable expected to be set";
        hasProxiedHosts = any (virtualHost: virtualHost.enable && virtualHost.proxied.enabled) (attrValues nginx.virtualHosts);
      in {
        upstreams' = {
          nginx'proxied = mkIf (warnEnable cfg.enable) {
            servers.local = {
              accessService = {
                system = systemConfig.name;
                name = "nginx";
                port = "proxied";
              };
            };
          };
        };
        virtualHosts = {
          fallback'proxied = mkIf cfg.enable {
            serverName = null;
            reuseport = mkAlmostOptionDefault true;
            default = mkAlmostOptionDefault true;
            listen'.proxied = {
              addr = mkAlmostOptionDefault cfg.listenAddr;
              port = mkAlmostOptionDefault cfg.listenPort;
            };
            locations."/".extraConfig = mkAlmostOptionDefault ''
              return 502;
            '';
          };
        };
        commonHttpConfig = mkIf cfg.enable ''
          map "$http_cf_connecting_ip" $proxied_remote_addr_cf {
            "" $remote_addr;
            default $http_cf_connecting_ip;
          }
          map "$http_x_real_ip" $proxied_remote_addr_x {
            "" $remote_addr;
            default $http_x_real_ip;
          }
          map "$http_x_forwarded_host" $proxied_host_x {
            "" $host;
            default $http_x_forwarded_host;
          }
          map "$http_x_forwarded_server" $proxied_forwarded_server_x {
            "" $proxied_host_x;
            default $http_x_forwarded_server;
          }
          map "$http_x_forwarded_proto" $proxied_scheme {
            "" $scheme;
            default $http_x_forwarded_proto;
          }
          map "$proxied_scheme" $proxied_https {
            "https" on;
            default "";
          }

          map "$proxied_cf" $proxied_remote_addr {
            "on" $proxied_remote_addr_cf;
            default $proxied_remote_addr_x;
          }
          map "$proxied_cf" $proxied_host {
            "on" $proxied_host_cf;
            default $proxied_host_x;
          }

          log_format combined_proxied '$proxied_remote_addr@$proxied_scheme proxied $remote_user@$proxied_host [$time_local]'
            ' "$request" $status $body_bytes_sent'
            ' "$http_referer" "$http_user_agent"';
          log_format combined_cloudflared '$proxied_remote_addr_cf@$proxied_scheme cloudflared@$http_cf_ray $remote_user@$proxied_host_cf [$time_local]'
            ' "$request" $status $body_bytes_sent'
            ' "$http_referer" "$http_user_agent"';
        '';
      };
      networking.firewall.interfaces.lan = mkIf nginx.enable {
        allowedTCPPorts = mkIf cfg.enable [cfg.listenPort];
      };
    };
  }
