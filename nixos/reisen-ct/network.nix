{
  lib,
  config,
  options,
  meta,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.avahi
  ];

  services.resolved.enable = true;
  systemd.services.avahi-daemon = mkIf (options ? proxmoxLXC && config.services.avahi.enable) {
    serviceConfig.ExecStartPre = mkIf config.services.resolved.enable [
      "+-${config.systemd.package}/bin/resolvectl mdns eth0 yes"
    ];
  };
  systemd.network.networks.eth0 = mkIf (! options ? proxmoxLXC) {
    matchConfig.Name = "eth0";
    linkConfig.Multicast = true;
    networkConfig.MulticastDNS = true;
  };

  boot.kernel.sysctl = {
    # not sure how to get it to overlap with subgid/idmap...
    "net.ipv4.ping_group_range" = "0 7999";
  };
}
