{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.attrsets) attrValues;
  inherit (lib.lists) concatMap toList elem;
  allExporters = let
    exporters = removeAttrs config.services.prometheus.exporters ["unifi-poller"];
  in
    concatMap toList (attrValues exporters);
in {
  config = {
    services.prometheus.exporters = {
      node = {
        port = 9091;
        extraFlags = [ "--collector.disable-defaults" ];
        enabledCollectors = mkMerge [
          (mkIf config.boot.supportedFilesystems.xfs or false [
            "xfs"
          ])
          (mkIf config.boot.supportedFilesystems.zfs or false [
            "zfs"
          ])
          (mkIf config.boot.supportedFilesystems.nfs or config.boot.supportedFilesystems.nfs4 or false [
            "nfs"
          ])
          (mkIf config.services.nfs.server.enable [
            "nfsd"
          ])
          (mkIf (!config.boot.isContainer) [
            "nvme"
            "hwmon"
            "thermal_zone"
          ])
          (mkIf config.powerManagement.enable [
            "powersupplyclass"
            "rapl"
          ])
          (mkIf (config.services.xserver.enable && elem "amdgpu" config.services.xserver.videoDrivers) [
            "drm"
          ])
          (mkIf (config.networking.wireless.enable || config.networking.wireless.iwd.enable || config.networking.networkmanager.enable) [
            "wifi"
          ])
          [
            "arp"
            "cpu"
            "cpufreq"
            "diskstats"
            "dmi"
            "entropy"
            "filesystem"
            "netdev"
            "sysctl"
            "systemd"
            "ethtool"
            "logind"
            "cgroups"
            "loadavg"
            "meminfo"
            "netstat"
            "os"
            "stat"
            "time"
            "uname"
            "vmstat"
          ]
        ];
      };
    };
    networking.firewall.interfaces.lan.allowedTCPPorts =
      map (
        exporter:
          mkIf (exporter.enable && !exporter.openFirewall) exporter.port
      )
      allExporters;
  };
}
