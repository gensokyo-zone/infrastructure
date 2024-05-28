{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
in {
  config = {
    services.prometheus.exporters = {
      node = mkMerge [
        {
          #enable = true;
          port = 9091;
          enabledCollectors = [
            "nfs"
          ];
        }
        (mkIf config.services.nfs.server.enable {
          enabledCollectors = [
            "nfsd"
          ];
        })
        (mkIf (!config.boot.isContainer) {
          enabledCollectors = [
            "nvme"
            "hwmon"
          ];
        })
        {
          enabledCollectors = [
            "arp"
            "cpu"
            "cpufreq"
            "diskstats"
            "dmi"
            "entropy"
            "filesystem"
            "netdev"
            "systemd"
            "sysctl"
            "systemd"
            "loadavg"
            "meminfo"
            "netstat"
            "os"
            "stat"
            "time"
            "uname"
            "vmstat"
            "zfs"
          ];
        }
      ];
    };
  };
}
