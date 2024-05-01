{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkOptionDefault;
  inherit (lib.options) mkOption;
  inherit (lib.lists) optionals;
  inherit (lib.strings) concatStringsSep;
  inherit (config.services) tailscale;
  inherit (config) networking;
  cfg = config.networking.access;
  cidrModule = {config, ...}: {
    options = with lib.types; {
      all = mkOption {
        type = listOf str;
        readOnly = true;
      };
      v4 = mkOption {
        type = listOf str;
        default = [];
      };
      v6 = mkOption {
        type = listOf str;
        default = [];
      };
    };
    config.all = mkOptionDefault (
      config.v4
      ++ optionals networking.enableIPv6 config.v6
    );
  };
in {
  options.networking.access = with lib.types; {
    cidrForNetwork = mkOption {
      type = attrsOf (submodule cidrModule);
      default = {};
    };
  };

  config.networking.access = {
    cidrForNetwork = {
      loopback = {
        v4 = [
          "127.0.0.0/8"
        ];
        v6 = [
          "::1"
        ];
      };
      local = {
        v4 = [
          "10.1.1.0/24"
        ];
        v6 = [
          "fd0a::/64"
          "fe80::/64"
        ];
      };
      int = {
        v4 = [
          "10.9.1.0/24"
        ];
        v6 = [
          "fd0c::/64"
        ];
      };
      tail = mkIf tailscale.enable {
        v4 = [
          "100.64.0.0/10"
        ];
        v6 = [
          "fd7a:115c:a1e0::/96"
          "fd7a:115c:a1e0:ab12::/64"
        ];
      };
      allLan = {
        v4 = cfg.cidrForNetwork.loopback.v4
          ++ cfg.cidrForNetwork.local.v4
          ++ cfg.cidrForNetwork.int.v4;
        v6 = cfg.cidrForNetwork.loopback.v6
          ++ cfg.cidrForNetwork.local.v6
          ++ cfg.cidrForNetwork.int.v6;
      };
      allLocal = {
        v4 = mkMerge [
          cfg.cidrForNetwork.allLan.v4
          (mkIf tailscale.enable cfg.cidrForNetwork.tail.v4)
        ];
        v6 = mkMerge [
          cfg.cidrForNetwork.allLan.v6
          (mkIf tailscale.enable cfg.cidrForNetwork.tail.v6)
        ];
      };
    };
    moduleArgAttrs = {
      inherit (cfg) cidrForNetwork;
      mkSnakeOil = pkgs.callPackage ../../../packages/snakeoil.nix {};
    };
  };

  config.networking = {
    firewall = {
      interfaces.local = {
        nftables.conditions = [
          "ip saddr { ${concatStringsSep ", " (cfg.cidrForNetwork.local.v4 ++ cfg.cidrForNetwork.int.v4)} }"
          (
            mkIf networking.enableIPv6
            "ip6 saddr { ${concatStringsSep ", " (cfg.cidrForNetwork.local.v6 ++ cfg.cidrForNetwork.int.v6)} }"
          )
        ];
      };
    };
  };
}
