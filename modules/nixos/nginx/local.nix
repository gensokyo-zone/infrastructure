{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkBefore mkOptionDefault;
  inherit (lib.strings) concatMapStringsSep optionalString;
  inherit (lib.lists) optionals;
  inherit (config.services) tailscale;
  inherit (config.networking.access) cidrForNetwork localaddrs;
  mkAddrVar = remoteAddr: varPrefix: ''
    set ${varPrefix}tailscale 0;
  '' + optionalString tailscale.enable ''
    if (${remoteAddr} ~ "^fd7a:115c:a1e0:(:|ab12:)") {
      set ${varPrefix}tailscale 1;
    }
    if (${remoteAddr} ~ "^100\.(6[4-9]|([7-9]|1[01])[0-9]|12[0-7])\.[0-9]+\.[0-9]+") {
      set ${varPrefix}tailscale 1;
    }
  '' + ''
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
    if (${varPrefix}localhost) {
      set ${varPrefix}client 1;
    }
  '';
  localModule = {config, ...}: let
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
        allowAddresses =
          cidrForNetwork.loopback.all
          ++ cidrForNetwork.local.all
          ++ optionals tailscale.enable cidrForNetwork.tail.all;
        allows =
          concatMapStringsSep "\n" mkAllow allowAddresses
          + optionalString localaddrs.enable ''
            include ${localaddrs.stateDir}/*.nginx.conf;
          '';
        allowDirectives = ''
          ${allows}
          deny all;
        '';
      in mkMerge [
        (mkIf cfg.emitDenyGlobal (mkBefore allowDirectives))
        (mkIf cfg.emitVars (mkBefore (mkAddrVar "$remote_addr" "$local_")))
        (mkIf cfg.emitVars (mkBefore (mkAddrVar "$x_remote_addr" "$x_local_")))
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
        type = attrsOf (submoduleWith {
          modules = [locationModule];
          shorthandOnlyDefinesConfig = true;
          specialArgs = {
            virtualHost = config;
          };
        });
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
      type = attrsOf (submoduleWith {
        modules = [hostModule];
        shorthandOnlyDefinesConfig = true;
        specialArgs = {
          nixosConfig = config;
        };
      });
    };
  };
}
