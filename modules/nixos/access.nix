{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkBefore mkAfter mkOptionDefault;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.lists) optionals;
  inherit (lib.strings) concatStringsSep optionalString;
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
    localaddrs = {
      enable =
        mkEnableOption "localaddrs"
        // {
          default = networking.firewall.interfaces.local.nftables.enable;
        };
      stateDir = mkOption {
        type = path;
        default = "/var/lib/localaddrs";
      };
      reloadScript = mkOption {
        type = path;
        readOnly = true;
      };
      nftablesInclude = mkOption {
        type = lines;
        readOnly = true;
      };
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
    localaddrs = {
      nftablesInclude = mkBefore (''
          define localrange6 = 2001:568::/29
        ''
        + optionalString cfg.localaddrs.enable ''
          include "${cfg.localaddrs.stateDir}/*.nft"
        '');
      reloadScript = let
        localaddrs-reload = pkgs.writeShellScript "localaddrs-reload" ''
          ${config.systemd.package}/bin/systemctl reload localaddrs 2>/dev/null ||
          ${config.systemd.package}/bin/systemctl restart localaddrs ||
          true
        '';
      in "${localaddrs-reload}";
    };
    moduleArgAttrs = {
      inherit (cfg) cidrForNetwork localaddrs;
      mkSnakeOil = pkgs.callPackage ../../packages/snakeoil.nix {};
    };
  };

  config.networking = {
    nftables.ruleset = mkBefore cfg.localaddrs.nftablesInclude;
    firewall = {
      interfaces.local = {
        nftables.conditions = [
          "ip saddr { ${concatStringsSep ", " cfg.cidrForNetwork.local.v4} }"
          (
            mkIf networking.enableIPv6
            "ip6 saddr { $localrange6, ${concatStringsSep ", " cfg.cidrForNetwork.local.v6} }"
          )
        ];
      };
    };
  };
  config.systemd.services = let
    localaddrs = pkgs.writeShellScript "localaddrs" ''
      set -eu
      getaddrs() {
        local PREFIX=$1 PATTERN=$2 IPADDRS
        IPADDRS=$(${pkgs.iproute2}/bin/ip -o addr show to "$PREFIX") || return $?
        IPADDRS=$(printf '%s\n' "$IPADDRS" | ${pkgs.gnugrep}/bin/grep -o "$PATTERN") || return $?
        if [[ -z $IPADDRS ]]; then
          return 1
        fi
        printf '%s\n' "$IPADDRS"
      }
      getaddrs4() {
        getaddrs 10.1.1.0/24 '[0-9]*\.[0-9.]*/[0-9]*'
      }
      getaddrs6() {
        getaddrs 2001:568::/29 '[0-9a-f:]*:[0-9a-f:]*/[0-9]*'
      }
      mkdir -p $STATE_DIRECTORY
      if LOCALADDRS4=$(getaddrs4); then
        printf '%s\n' "$LOCALADDRS4" > $STATE_DIRECTORY/localaddrs4
      else
        echo WARNING: localaddr4 not found >&2
      fi
      if LOCALADDRS6=$(getaddrs6); then
        echo "$LOCALADDRS6" > $STATE_DIRECTORY/localaddrs6
      else
        echo WARNING: localaddr6 not found >&2
      fi
    '';
    localaddrs-nftables = pkgs.writeShellScript "localaddrs-nftables" ''
      set -eu
      LOCALADDR6=$(head -n1 "${cfg.localaddrs.stateDir}/localaddrs6" || true)
      if [[ -n $LOCALADDR6 ]]; then
        printf 'redefine localrange6 = %s\n' "$LOCALADDR6" > ${cfg.localaddrs.stateDir}/ranges.nft
      fi
    '';
    localaddrs-nginx = pkgs.writeShellScript "localaddrs-nginx" ''
      set -eu
      LOCALADDR6=$(head -n1 "${cfg.localaddrs.stateDir}/localaddrs6" || true)
      if [[ -n $LOCALADDR6 ]]; then
        printf 'allow %s;\n' "$LOCALADDR6" > ${cfg.localaddrs.stateDir}/allow.nginx.conf
      fi
      LOCALADDR4=$(head -n1 "${cfg.localaddrs.stateDir}/localaddrs4" || true)
      if [[ -n $LOCALADDR4 ]]; then
        printf 'allow %s;\n' "$LOCALADDR4" >> ${cfg.localaddrs.stateDir}/allow.nginx.conf
      fi
    '';
  in {
    localaddrs = mkIf cfg.localaddrs.enable {
      unitConfig = {
        After = ["network-online.target"];
      };
      serviceConfig = rec {
        StateDirectory = "localaddrs";
        ExecStart = mkMerge [
          ["${localaddrs}"]
          (mkIf networking.nftables.enable (mkAfter [
            "${localaddrs-nftables}"
          ]))
          (mkIf config.services.nginx.enable (mkAfter [
            "${localaddrs-nginx}"
          ]))
        ];
        ExecReload = ExecStart;
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
    nftables = mkIf (networking.nftables.enable && cfg.localaddrs.enable) rec {
      wants = ["localaddrs.service"];
      serviceConfig = {
        ExecReload = mkBefore [
          "+${cfg.localaddrs.reloadScript}"
        ];
      };
    };
    nginx = mkIf (config.services.nginx.enable && cfg.localaddrs.enable) rec {
      wants = ["localaddrs.service"];
      after = wants;
      serviceConfig = {
        ExecReload = mkBefore [
          "+${cfg.localaddrs.reloadScript}"
        ];
      };
    };
  };
}
