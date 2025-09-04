{
  lib,
  gensokyo-zone,
  config,
  options,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf;
in {
  systemd.services.avahi-daemon = mkIf (options ? proxmoxLXC && config.services.avahi.enable) {
    serviceConfig.ExecStartPre = mkIf config.services.resolved.enable [
      "+-${config.systemd.package}/bin/resolvectl mdns ${config.systemd.network.networks._00-local.name or "eth0"} yes"
    ];
  };
  systemd.network.networks._00-local = mkIf (! options ? proxmoxLXC) {
    name = mkAlmostOptionDefault "ens18";
    linkConfig.Multicast = true;
    networkConfig.MulticastDNS = true;
  };

  boot.kernel.sysctl = {
    # not sure how to get it to overlap with subgid/idmap...
    "net.ipv4.ping_group_range" = "0 7999";
  };
}
