{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.tautulli;
in {
  services.tautulli = {
    enable = mkDefault true;
    port = mkDefault 8181;
  };
  systemd.services.tautulli = mkIf cfg.enable {
    serviceConfig = {
      BindPaths = [
        "/mnt/caches/plex/tautulli/cache:${cfg.dataDir}/cache"
      ];
    };
  };
}
