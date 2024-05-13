{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkOptionDefault;
  inherit (lib.strings) concatMapStringsSep optionalString;
  inherit (config.services) tailscale;
  inherit (config.networking.access) cidrForNetwork localaddrs;
  mkAddrVar = remoteAddr: varPrefix:
    ''
      set ${varPrefix}tailscale 0;
    ''
    + optionalString tailscale.enable ''
      if (${remoteAddr} ~ "^fd7a:115c:a1e0:(:|ab12:)") {
        set ${varPrefix}tailscale 1;
      }
      if (${remoteAddr} ~ "^100\.(6[4-9]|([7-9]|1[01])[0-9]|12[0-7])\.[0-9]+\.[0-9]+") {
        set ${varPrefix}tailscale 1;
      }
    ''
    + ''
      set ${varPrefix}lan 0;
      if (${remoteAddr} ~ "^10\.1\.1\.[0-9]+") {
        set ${varPrefix}lan 1;
      }
      if (${remoteAddr} ~ "^fd0a::") {
        set ${varPrefix}lan 1;
      }
      if (${remoteAddr} ~ "^fe80::") {
        set ${varPrefix}lan 1;
      }
      set ${varPrefix}int 0;
      if (${remoteAddr} ~ "^10\.9\.1\.[0-9]+") {
        set ${varPrefix}lan 1;
      }
      if (${remoteAddr} ~ "^fd0c::") {
        set ${varPrefix}int 1;
      }
      set ${varPrefix}localhost 0;
      if (${remoteAddr} = "::1") {
        set ${varPrefix}localhost 1;
      }
      if (${remoteAddr} ~ "127\.0\.0\.[0-9]+") {
        set ${varPrefix}localhost 1;
      }
      set ${varPrefix}client 0;
      if (${varPrefix}tailscale) {
        set ${varPrefix}client 1;
      }
      if (${varPrefix}lan) {
        set ${varPrefix}client 1;
      }
      if (${varPrefix}int) {
        set ${varPrefix}client 1;
      }
      if (${varPrefix}localhost) {
        set ${varPrefix}client 1;
      }
    '';
  localModule = {
    config,
    xvars,
    ...
  }: let
    cfg = config.local;
  in {
    options.local = with lib.types; {
      enable = mkOption {
        type = bool;
        description = "for local traffic only";
        defaultText = literalExpression "false";
      };
      denyGlobal = mkOption {
        type = bool;
        defaultText = literalExpression "config.local.enable";
      };
      trusted = mkOption {
        type = bool;
        defaultText = literalExpression "config.local.denyGlobal";
      };
      vars.enable = mkEnableOption "local vars";
      emitDenyGlobal = mkOption {
        internal = true;
        type = bool;
        default = cfg.denyGlobal;
      };
      emitVars = mkOption {
        internal = true;
        type = bool;
        default = cfg.vars.enable;
      };
    };
    config = {
      extraConfig = let
        mkAllow = cidr: "allow ${cidr};";
        allows =
          concatMapStringsSep "\n" mkAllow cidrForNetwork.allLocal.all
          + optionalString localaddrs.enable ''
            include ${localaddrs.stateDir}/*.nginx.conf;
          '';
        allowDirectives = ''
          ${allows}
          deny all;
        '';
      in
        mkMerge [
          (mkIf cfg.emitDenyGlobal (mkBefore allowDirectives))
          (mkIf cfg.emitVars (mkBefore (mkAddrVar "$remote_addr" "$local_")))
          (mkIf (cfg.emitVars && config.xvars.enable) (mkBefore (mkAddrVar (xvars.remote_addr.get) "$x_local_")))
        ];
    };
  };
  locationModule = {
    config,
    virtualHost,
    ...
  }: let
    cfg = config.local;
  in {
    imports = [
      localModule
    ];

    config.local = {
      enable = mkOptionDefault virtualHost.local.enable;
      denyGlobal = mkOptionDefault virtualHost.local.denyGlobal;
      trusted = mkOptionDefault virtualHost.local.trusted;
      emitDenyGlobal = cfg.denyGlobal && !virtualHost.local.emitDenyGlobal;
      emitVars = cfg.vars.enable && !virtualHost.local.vars.enable;
    };
  };
  hostModule = {config, ...}: let
    cfg = config.local;
  in {
    imports = [localModule];

    options = with lib.types; {
      locations = mkOption {
        type = attrsOf (submodule [locationModule]);
      };
    };

    config.local = {
      enable = mkOptionDefault false;
      denyGlobal = mkOptionDefault cfg.enable;
      trusted = mkOptionDefault cfg.denyGlobal;
    };
  };
in {
  options = with lib.types; {
    services.nginx.virtualHosts = mkOption {
      type = attrsOf (submodule [hostModule]);
    };
  };
}
