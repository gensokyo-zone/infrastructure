let
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
    if ($http_x_forwarded_host) {
      ${xvars.init "host" "$http_x_forwarded_host"}
    }
    if ($http_x_forwarded_server) {
      ${xvars.init "forwarded_server" "$http_x_forwarded_server"}
    }
  '';
  locationModule = {
    config,
    virtualHost,
    xvars,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mkJustBefore mkAlmostOptionDefault;
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
      xvars.enable = mkIf cfg.enabled true;
      extraConfig = mkMerge [
        (mkIf emitVars (
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
    inherit (gensokyo-zone.lib) mkAlmostOptionDefault orderJustBefore unmerged;
    inherit (lib.options) mkOption;
    inherit (lib.modules) mkIf mkOrder mkDefault;
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
            ingressSettings.${config.serverName} = {
              service = "${scheme}://localhost:${toString listen.port}";
              originRequest.${
                if scheme == "https"
                then "noTLSVerify"
                else null
              } =
                true;
            };
            getIngress = {}: unmerged.mergeAttrs cfg.cloudflared.ingressSettings;
          };
      };
      xvars.enable = mkIf cfg.enabled true;
      local.denyGlobal = mkIf listenProxied (mkDefault true);
      listen' = mkIf listenProxied {
        proxied = {
          addr = mkAlmostOptionDefault nginx.proxied.listenAddr;
          port = mkAlmostOptionDefault nginx.proxied.listenPort;
        };
      };
      extraConfig = mkIf (cfg.enabled && config.xvars.enable) (
        mkOrder (orderJustBefore + 25) (xHeadersProxied {inherit xvars;})
      );
    };
  };
in
  {
    config,
    system,
    gensokyo-zone,
    lib,
    ...
  }: let
    inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
    inherit (lib.options) mkOption mkEnableOption;
    inherit (lib.modules) mkIf mkOptionDefault;
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
                system = system.name;
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
      };
      networking.firewall.interfaces.lan = mkIf nginx.enable {
        allowedTCPPorts = mkIf cfg.enable [cfg.listenPort];
      };
    };
  }
