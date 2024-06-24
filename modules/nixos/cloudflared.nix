let
  tunnelModule = {pkgs, config, lib, ...}: let
    inherit (lib.options) mkOption mkEnableOption;
    settingsFormat = pkgs.formats.json {};
  in {
    options = with lib.types; {
      extraArgs = mkOption {
        type = listOf str;
        default = [];
      };
      extraTunnel = {
        enable =
          mkEnableOption "extra tunnels"
          // {
            default = config.extraTunnel.ingress != {};
          };
        ingress = mkOption {
          inherit (settingsFormat) type;
          default = {};
        };
      };
    };
  };
in {
  pkgs,
  config,
  utils,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (lib.attrsets) mapAttrsToList mapAttrs' nameValuePair filterAttrsRecursive;
  inherit (lib.lists) singleton;
  inherit (lib.modules) mkIf mkMerge mkForce;
  inherit (lib.options) mkOption;
  cfg = config.services.cloudflared;
in {
  options.services.cloudflared = with lib.types; {
    metricsPort = mkOption {
      type = nullOr port;
      default = null;
    };
    metricsBind = mkOption {
      type = str;
      default = "127.0.0.1";
    };
    extraArgs = mkOption {
      type = listOf str;
      default = [];
    };
    tunnels = mkOption {
      type = attrsOf (submoduleWith {
        modules = [tunnelModule];
        shorthandOnlyDefinesConfig = true;
        specialArgs = {
          inherit pkgs utils gensokyo-zone;
        };
      });
    };
  };
  config.services.cloudflared = {
    extraArgs = mkIf (cfg.metricsPort != null) [
      "--metrics" "${cfg.metricsBind}:${toString cfg.metricsPort}"
    ];
  };
  config.systemd.services = let
    filterConfig = filterAttrsRecursive (_: v: ! builtins.elem v [null [] {}]);
    mapIngress = hostname: ingress:
      {
        inherit hostname;
      }
      // filterConfig (filterConfig ingress);
  in
    mkIf cfg.enable (mapAttrs' (uuid: tunnel: let
      RuntimeDirectory = "cloudflared-tunnel-${uuid}";
      settings = {
        tunnel = uuid;
        credentials-file = tunnel.credentialsFile;
        warp-routing = filterConfig tunnel.warp-routing;
        originRequest = filterConfig tunnel.originRequest;
        ingress =
          mapAttrsToList mapIngress tunnel.ingress
          ++ mapAttrsToList mapIngress tunnel.extraTunnel.ingress
          ++ singleton {service = tunnel.default;};
      };
      configPath =
        if tunnel.extraTunnel.enable
        then "/run/${RuntimeDirectory}/config.yml"
        else pkgs.writeText "cloudflared.yml" (builtins.toJSON settings);
      args = [
        "--config=${configPath}"
        "--no-autoupdate"
      ] ++ cfg.extraArgs ++ tunnel.extraArgs;
    in
      nameValuePair "cloudflared-tunnel-${uuid}" (mkMerge [
        {
          after = mkIf config.services.tailscale.enable ["tailscale-autoconnect.service"];
          serviceConfig = {
            RestartSec = 10;
            ExecStart = mkForce [
              "${cfg.package}/bin/cloudflared tunnel ${utils.escapeSystemdExecArgs args} run"
            ];
          };
        }
        (mkIf tunnel.extraTunnel.enable {
          serviceConfig = {
            inherit RuntimeDirectory;
            ExecStartPre = [
              (pkgs.writeShellScript "cloudflared-tunnel-${uuid}-prepare" ''
                ${utils.genJqSecretsReplacementSnippet settings configPath}
              '')
            ];
          };
        })
      ]))
    cfg.tunnels);
}
