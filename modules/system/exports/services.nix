{
  config,
  name,
  lib,
  gensokyo-zone,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.modules) mkIf mkMerge mkOptionDefault;
  inherit (lib.attrsets) mapAttrsToList getAttrFromPath genAttrs;
  inherit (lib.trivial) mapNullable;
  inherit (lib.strings) concatStringsSep;
  cfg = config.exports;
  portModule = {
    config,
    name,
    service,
    ...
  }: {
    options = with lib.types; {
      enable =
        mkEnableOption "port"
        // {
          default = true;
        };
      name = mkOption {
        type = str;
        default = name;
      };
      displayName = mkOption {
        type = nullOr str;
        default =
          if config.name == "default"
          then null
          else if config.ssl && (config.name == "ssl" || config.name == "https")
          then "SSL"
          else config.name;
      };
      listen = mkOption {
        type = enum ["wan" "lan" "int" "tail" "localhost"];
      };
      protocol = mkOption {
        type = nullOr (enum ["http" "https"]);
        default = null;
      };
      transport = mkOption {
        type = enum ["tcp" "udp" "unix"];
      };
      path = mkOption {
        type = nullOr path;
        default = null;
        description = "unix socket path";
      };
      ssl = mkOption {
        type = bool;
        default = false;
      };
      starttls = mkOption {
        type = bool;
        default = false;
      };
      port = mkOption {
        type = nullOr int;
      };
    };
    config = {
      transport = mkMerge [
        (mkIf (config.protocol == "http" || config.protocol == "https") (mkOptionDefault "tcp"))
        (mkIf config.ssl (mkOptionDefault "tcp"))
      ];
      ssl = mkIf (config.protocol == "https") (
        mkAlmostOptionDefault true
      );
      listen = mkOptionDefault service.defaults.port.listen;
    };
  };
  serviceModule = {
    systemConfig,
    config,
    name,
    machine,
    gensokyo-zone,
    ...
  }: {
    options = with lib.types; {
      enable = mkEnableOption "hosted service";
      name = mkOption {
        type = str;
        default = name;
      };
      displayName = mkOption {
        type = str;
        default = name;
      };
      id = mkOption {
        type = str;
        default = config.name;
      };
      ports = mkOption {
        type = attrsOf (submoduleWith {
          modules = [portModule];
          specialArgs = {
            inherit gensokyo-zone machine systemConfig;
            service = config;
          };
        });
      };
      nixos = {
        serviceAttr = mkOption {
          type = nullOr str;
          default = null;
        };
        serviceAttrPath = mkOption {
          type = nullOr (listOf str);
        };
        assertions = mkOption {
          type = listOf (functionTo attrs);
          default = [];
        };
      };
      defaults = {
        port = {
          listen = mkOption {
            type = str;
            default = "int";
          };
        };
      };
    };
    config = {
      nixos = {
        serviceAttrPath = mkOptionDefault (
          mapNullable (serviceAttr: ["services" config.nixos.serviceAttr]) config.nixos.serviceAttr
        );
        assertions = let
          serviceConfig = getAttrFromPath config.nixos.serviceAttrPath;
          mkAssertion = f: nixosConfig: let
            cfg = serviceConfig nixosConfig;
          in
            f nixosConfig cfg;
          enableAssertion = nixosConfig: cfg: {
            assertion = (! cfg ? enable) || (config.enable == cfg.enable);
            message = "enable == nixosConfig.${concatStringsSep "." config.nixos.serviceAttrPath}.enable";
          };
        in [
          (mkIf (config.nixos.serviceAttrPath != null) (
            mkAssertion enableAssertion
          ))
        ];
      };
    };
  };
  nixosModule = {
    config,
    systemConfig,
    ...
  }: let
    mapAssertion = service: a: let
      res = a config;
    in
      res
      // {
        message = "system.exports.${service.name}: " + res.message or "assertion failed";
      };
    assertions = mapAttrsToList (_: service: map (mapAssertion service) service.nixos.assertions) systemConfig.exports.services;
  in {
    config = {
      assertions = mkMerge assertions;
      # TODO: export ports via firewall according to enable/listen/etc
    };
  };
in {
  options.exports = with lib.types; {
    defaultServices =
      mkEnableOption "common base services"
      // {
        default = config.type == "NixOS";
      };
    services = mkOption {
      type = attrsOf (submoduleWith {
        modules = [serviceModule];
        specialArgs = {
          inherit gensokyo-zone;
          machine = name;
          systemConfig = config;
        };
      });
      default = {};
    };
  };

  config = {
    modules = mkIf (config.type == "NixOS") [
      nixosModule
    ];
    exports = let
      defaultServices = genAttrs [
        "sshd"
        "prometheus-exporters-node"
        "promtail"
      ] (_: {enable = mkAlmostOptionDefault true;});
    in {
      services = mkIf cfg.defaultServices defaultServices;
    };
  };
}
