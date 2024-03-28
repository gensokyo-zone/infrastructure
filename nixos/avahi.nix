{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkDefault mkIf mkOptionDefault;
  inherit (lib.strings) makeBinPath;
  cfg = config.services.avahi;
in {
  services.avahi = {
    enable = mkDefault true;
    ipv6 = mkDefault config.networking.enableIPv6;
    nssmdns4 = mkIf (!config.services.resolved.enable) (mkDefault true);
    nssmdns6 = mkIf (!config.services.resolved.enable) (mkDefault true);
    publish = {
      enable = mkDefault true;
      domain = mkDefault true;
      addresses = mkDefault true;
      userServices = mkDefault true;
    };
    wideArea = mkDefault false;
  };

  systemd.services = let
    # work around a weird bug or interaction in avahi-daemon
    RestartSec = 2;
    daemon = "avahi-daemon.service";
    avahi-daemon-watchdog = pkgs.writeShellScript "avahi-daemon-watchdog" ''
      set -eu
      export PATH="$PATH:${makeBinPath [config.systemd.package pkgs.coreutils pkgs.gnugrep]}"
      while read -r line; do
        if [[ $line = *"Host name conflict, retrying with "* ]]; then
          if systemctl is-active ${daemon} > /dev/null; then
            echo restarting avahi-daemon due to host name conflict... >&2
            systemctl stop ${daemon}
            sleep ${toString RestartSec}
            systemctl start ${daemon}
          fi
        fi
      done < <(journalctl -n 0 -o cat -feu ${daemon})
    '';
  in
    mkIf (cfg.enable && cfg.publish.enable) {
      avahi-daemon = {
        serviceConfig = {
          inherit RestartSec;
        };
      };
      avahi-daemon-watchdog = {
        wantedBy = [daemon];
        serviceConfig = {
          Type = mkOptionDefault "exec";
          ExecStart = [
            "${avahi-daemon-watchdog}"
          ];
          Restart = mkOptionDefault "on-failure";
          RestartSec = mkOptionDefault RestartSec;
        };
      };
    };
}
