{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) concatMap toList;
  allExporters = let
    exporters = removeAttrs config.services.prometheus.exporters ["unifi-poller"];
  in
    concatMap toList (attrValues exporters);
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
    networking.firewall.interfaces.lan.allowedTCPPorts =
      map (
        exporter:
          mkIf (exporter.enable && !exporter.openFirewall) exporter.port
      )
      allExporters;
  };
}
