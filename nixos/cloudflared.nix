{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.cloudflared;
in {
  config = {
    services.cloudflared = {
      enable = mkDefault true;
      metricsPort = mkDefault 3011;
      metricsBind = "[::]";
      systemd.extraServiceSettings = {
        serviceConfig.User = mkDefault "cloudflared";
      };
    };
    users = mkIf cfg.enable {
      users.cloudflared = {
        group = mkDefault "cloudflared";
        isSystemUser = true;
      };
      groups.cloudflared = {};
    };
    networking.firewall = mkIf cfg.enable {
      interfaces.lan.allowedTCPPorts = mkIf (cfg.metricsPort != null) [
        cfg.metricsPort
      ];
    };
    boot.kernel.sysctl = mkIf (!config.boot.isContainer && cfg.enable) {
      # https://github.com/quic-go/quic-go/wiki/UDP-Buffer-Sizes
      "net.core.rmem_max" = mkDefault 7500000;
      "net.core.wmem_max" = mkDefault 7500000;
    };
  };
}
