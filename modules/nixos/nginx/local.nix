{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkBefore mkOptionDefault;
  inherit (lib.strings) concatMapStringsSep optionalString;
  inherit (lib.lists) optionals;
  inherit (config.services) tailscale;
  inherit (config.networking.access) cidrForNetwork localaddrs;
  localModule = {config, ...}: {
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
      emitDenyGlobal = mkOption {
        internal = true;
        type = bool;
        default = config.local.denyGlobal;
      };
    };
    config = mkIf config.local.emitDenyGlobal {
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
      in
        mkBefore ''
          ${allows}
          deny all;
        '';
    };
  };
  locationModule = {
    config,
    virtualHost,
    ...
  }: {
    imports = [
      localModule
    ];

    config.local = {
      enable = mkOptionDefault virtualHost.local.enable;
      denyGlobal = mkOptionDefault virtualHost.local.denyGlobal;
      trusted = mkOptionDefault virtualHost.local.trusted;
      emitDenyGlobal = config.local.denyGlobal && !virtualHost.local.emitDenyGlobal;
    };
  };
  hostModule = {config, ...}: {
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
      denyGlobal = mkOptionDefault config.local.enable;
      trusted = mkOptionDefault config.local.denyGlobal;
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
