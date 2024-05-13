{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkBefore mkAfter;
  inherit (lib.options) mkOption mkEnableOption;
  inherit (lib.strings) optionalString;
  inherit (config) networking;
  cfg = config.networking.access.localaddrs;
in {
  options.networking.access.localaddrs = with lib.types; {
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

  config.networking.access = {
    localaddrs = {
      nftablesInclude = mkBefore (''
          define localrange6 = 2001:568::/29
        ''
        + optionalString cfg.enable ''
          include "${cfg.stateDir}/*.nft"
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
      inherit (cfg) localaddrs;
    };
  };

  config.networking = {
    nftables.ruleset = mkIf cfg.enable (mkBefore cfg.nftablesInclude);
    firewall = {
      interfaces.local = {
        nftables.conditions = mkIf (cfg.enable && networking.enableIPv6) ["ip6 saddr $localrange6"];
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
      stripcidr() {
        local IPADDR
        while read -r IPADDR; do
          if [[ $IPADDR = ?*:?*:?*:?*:?*:?*:?*:?*/64 ]]; then
            echo ''${IPADDR%:?*:?*:?*:?*/64}::/64
          elif [[ $IPADDR = ?*:?*:?*:?*::*/64 ]] || [[ $IPADDR = ?*::?*:?*:?*:?*/64 ]]; then
            echo ''${IPADDR%::*/64}::/64
          elif [[ $IPADDR = *.*.*.*/24 ]]; then
            echo "''${IPADDR%.*/24}.0/24"
          else
            echo "WARNING: localaddrs failed to parse CIDR: $IPADDR" >&2
            echo "$IPADDR"
          fi
        done
      }
      mkdir -p $STATE_DIRECTORY
      if LOCALADDRS4=$(getaddrs4); then
        printf '%s\n' "$LOCALADDRS4" > $STATE_DIRECTORY/localaddrs4
        stripcidr <<<"$LOCALADDRS4" > $STATE_DIRECTORY/localcidrs4
      else
        echo WARNING: localaddr4 not found >&2
      fi
      if LOCALADDRS6=$(getaddrs6); then
        echo "$LOCALADDRS6" > $STATE_DIRECTORY/localaddrs6
        stripcidr <<<"$LOCALADDRS6" > $STATE_DIRECTORY/localcidrs6
      else
        echo WARNING: localaddr6 not found >&2
      fi
    '';
    localaddrs-nftables = pkgs.writeShellScript "localaddrs-nftables" ''
      set -eu
      LOCALADDR6=$(head -n1 "${cfg.stateDir}/localcidrs6" || true)
      if [[ -n $LOCALADDR6 ]]; then
        printf 'redefine localrange6 = %s\n' "$LOCALADDR6" > ${cfg.stateDir}/ranges.nft
      fi
    '';
    localaddrs-nginx = pkgs.writeShellScript "localaddrs-nginx" ''
      set -eu
      LOCALADDR6=$(head -n1 "${cfg.stateDir}/localcidrs6" || true)
      if [[ -n $LOCALADDR6 ]]; then
        printf 'allow %s;\n' "$LOCALADDR6" > ${cfg.stateDir}/allow.nginx.conf
      fi
      LOCALADDR4=$(head -n1 "${cfg.stateDir}/localcidrs4" || true)
      if [[ -n $LOCALADDR4 ]]; then
        printf 'allow %s;\n' "$LOCALADDR4" >> ${cfg.stateDir}/allow.nginx.conf
      fi
    '';
  in {
    localaddrs = mkIf cfg.enable {
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
    nftables = mkIf (networking.nftables.enable && cfg.enable) {
      wants = ["localaddrs.service"];
      serviceConfig = {
        ExecReload = mkBefore [
          "+${cfg.reloadScript}"
        ];
      };
    };
    nginx = mkIf (config.services.nginx.enable && cfg.enable) rec {
      wants = ["localaddrs.service"];
      after = wants;
      serviceConfig = {
        ExecReload = mkBefore [
          "+${cfg.reloadScript}"
        ];
      };
    };
  };
}
