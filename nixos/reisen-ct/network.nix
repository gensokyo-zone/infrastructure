{
  lib,
  config,
  options,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
in {
  services.resolved.enable = true;
  services.avahi = {
    enable = mkDefault true;
    ipv6 = mkDefault config.networking.enableIPv6;
    publish = {
      enable = mkDefault true;
      domain = mkDefault true;
      addresses = mkDefault true;
      userServices = mkDefault true;
    };
    wideArea = mkDefault false;
  };
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
}
