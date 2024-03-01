{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.cloudflared;
in {
  config = {
    services.cloudflared.enable = mkDefault true;
    boot.kernel.sysctl = mkIf (!config.boot.isContainer && cfg.enable) {
      # https://github.com/quic-go/quic-go/wiki/UDP-Buffer-Sizes
      "net.core.rmem_max" = mkDefault 2500000;
      "net.core.wmem_max" = mkDefault 2500000;
    };
  };
}
