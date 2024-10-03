{
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkIf mkForce mkDefault;
  inherit (lib.attrsets) mapAttrs' filterAttrs mapAttrsToList nameValuePair;
  inherit (lib.strings) escapeShellArg concatStringsSep;
  cfg = config.services.plex;
  plexCaches = {
    mesa_shader_cache.path = null;
    Cache = {};
    Logs = {};
    CrashReports.subpath = "Crash Reports";
    Diagnostics = {};
    Drivers = {};
    Codecs = {};
    Scanners = {};
    Updates = {};
    Caches.subpath = "Plug-in Support/Caches";
  };
in {
  services.plex.enable = mkDefault true;
  systemd.services.plex = mkIf cfg.enable {
    gensokyo-zone = {
      sharedMounts.plex.path = mkDefault cfg.dataDir;
      cacheMounts = mapAttrs' (name: _: nameValuePair "plex/${name}" {
        path = mkDefault "${cfg.dataDir}/${name}";
      }) plexCaches;
    };
    # /var/lib/plex/mesa_shader_cache
    environment.MESA_SHADER_CACHE_DIR = mkDefault cfg.dataDir;
    serviceConfig = {
      ExecStartPre = let
        ln = "${pkgs.coreutils}/bin/ln";
        install = "${pkgs.coreutils}/bin/install";
        # systemd doesn't seem to like spaces so use a symlink instead...
        mkCacheSetup = name: { path ? "Plex Media Server/${subpath}", subpath ? name }:
          ''${ln} -srfT "$PLEX_DATADIR/"${escapeShellArg name} "$PLEX_DATADIR/"${escapeShellArg path}'';
        cacheSetup = mapAttrsToList mkCacheSetup (filterAttrs (_: cache: cache.path or "" != null) plexCaches);
        preStartScript = pkgs.writeShellScript "plex-run-prestart" ''
          set -eu

          if [[ ! -d $PLEX_DATADIR ]]; then
            ${install} -d -m 0755 -o ${escapeShellArg cfg.user} -g ${escapeShellArg cfg.group} "$PLEX_DATADIR/Plex Media Server"
          fi
          if [[ ! -d $PLEX_DATADIR/Databases ]]; then
            ${install} -d -m 0755 -o ${escapeShellArg cfg.user} -g ${escapeShellArg cfg.group} "$PLEX_DATADIR/Databases"
          fi
          ${concatStringsSep "\n" cacheSetup}
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
