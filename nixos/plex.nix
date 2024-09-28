{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkIf mkForce mkDefault;
  inherit (lib.strings) escapeShellArg;
  cfg = config.services.plex;
in {
  services.plex.enable = mkDefault true;
  systemd.services.plex = mkIf cfg.enable {
    gensokyo-zone = {
      sharedMounts.plex.path = mkDefault cfg.dataDir;
      cacheMounts = {
        "plex/Cache" = {
          path = mkDefault "${cfg.dataDir}/Cache";
        };
        "plex/Logs" = {
          path = mkDefault "${cfg.dataDir}/Logs";
        };
        "plex/mesa_shader_cache" = {
          path = mkDefault "${cfg.dataDir}/mesa_shader_cache";
        };
      };
    };
    # /var/lib/plex/mesa_shader_cache
    environment.MESA_SHADER_CACHE_DIR = mkDefault cfg.dataDir;
    serviceConfig = {
      ExecStartPre = let
        # systemd doesn't seem to like spaces so use a symlink instead...
        preStartScript = pkgs.writeShellScript "plex-run-prestart" ''
          set -eu

          if [[ ! -d $PLEX_DATADIR ]]; then
            ${pkgs.coreutils}/bin/install -d -m 0755 -o ${escapeShellArg cfg.user} -g ${escapeShellArg cfg.group} "$PLEX_DATADIR/Plex Media Server"
          fi
          ${pkgs.coreutils}/bin/ln -sfT ../Cache "$PLEX_DATADIR/Plex Media Server/Cache"
          ${pkgs.coreutils}/bin/ln -sfT ../Logs "$PLEX_DATADIR/Plex Media Server/Logs"
        '';
      in
        mkForce [
          ''!${preStartScript}''
        ];
      # KillMode = "mixed" doesn't behave as expected...
      TimeoutStopSec = 5;
    };
  };

  # Plex Media Server:
  #
  # TCP:
  # * 32400 - direct HTTP access - we don't want to open this considering we're reverse proxying
  # * 8324 - Roku via Plex Companion
  # * 32469 - Plex DLNA Server
  # UDP:
  # * 1900 - DLNA
  # * 32410, 32412, 32413, 32414 - GDM Network Discovery

  networking.firewall.interfaces.local = {
    allowedTCPPorts = [cfg.port 8324 32469];
    allowedUDPPorts = [1900 32410 32412 32413 32414];
  };
}
