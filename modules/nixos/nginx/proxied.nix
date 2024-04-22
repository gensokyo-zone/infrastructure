{
  lib,
  inputs,
  ...
}: let
  inherit (inputs.self.lib.lib) mkJustBefore mkAlmostOptionDefault orderJustBefore;
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkMerge mkOrder mkDefault mkOptionDefault;
  xHeadersProxied = { xvars }: ''
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
  locationModule = { config, virtualHost, xvars, ... }: let
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
          mkJustBefore (xHeadersProxied { inherit xvars; })
        ))
      ];
    };
  };
  hostModule = { config, xvars, ... }: let
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
      };
      locations = mkOption {
        type = attrsOf (submoduleWith {
          modules = [ locationModule ];
          shorthandOnlyDefinesConfig = true;
        });
      };
    };

    config = {
      xvars.enable = mkIf cfg.enabled true;
      local.denyGlobal = mkIf (cfg.enable == "cloudflared") (mkDefault true);
      extraConfig = mkIf (cfg.enabled && config.xvars.enable) (
        mkOrder (orderJustBefore + 25) (xHeadersProxied { inherit xvars; })
      );
    };
  };
in {
  options = with lib.types; {
    services.nginx.virtualHosts = mkOption {
      type = attrsOf (submodule [hostModule]);
    };
  };
}
