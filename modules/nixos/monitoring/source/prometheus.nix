{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  inherit (lib.attrsets) mapAttrsToList;
  inherit (lib.lists) any toList elem;
in {
  config = {
    services.prometheus.exporters = {
      node = {
        port = 9091;
        extraFlags = ["--collector.disable-defaults"];
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
    networking.firewall.interfaces.lan.allowedTCPPorts = let
      # blacklist broken/deprecated exporters
      allExporters = removeAttrs config.services.prometheus.exporters ["unifi-poller" "minio"];
      enablePort = fallback: exporter: exporter.enable or fallback && !exporter.openFirewall or (!fallback);
      mkExporterPorts = name: exporters': let
        exporters = toList exporters';
        allowedTCPPorts = map mkExporterPort exporters;
        res = builtins.tryEval (any (enablePort true) exporters);
        cond = lib.warnIf (!res.success) "broken prometheus exporter: ${name}" res.value;
      in
        mkIf cond allowedTCPPorts;
      mkExporterPort = exporter: mkIf (enablePort false exporter) exporter.port;
    in
      mkMerge (mapAttrsToList mkExporterPorts allExporters);
  };
}
