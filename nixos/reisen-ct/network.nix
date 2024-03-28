{
  lib,
  config,
  options,
  meta,
  access,
  ...
}: let
  inherit (lib.modules) mkIf mkBefore mkOrder;
  enableDns = !config.services.dnsmasq.enable && config.networking.hostName != "utsuho" && config.networking.hostName != "ct";
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.avahi
  ];

  #services.resolved.enable = mkIf enableDns false;
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
  networking.nameservers' = mkIf enableDns (mkBefore [
    { address = access.getAddressFor "utsuho" "lan"; }
  ]);
  # prioritize our resolver over systemd-resolved!
  system.nssDatabases.hosts = let
    avahiResolverEnabled = config.services.avahi.enable && (config.services.avahi.nssmdns4 || config.services.avahi.nssmdns4);
  in mkIf (enableDns && (config.services.resolved.enable || avahiResolverEnabled)) (mkOrder 499 ["dns"]);
  services.resolved.extraConfig = mkIf enableDns ''
    DNSStubListener=no
  '';

  boot.kernel.sysctl = {
    # not sure how to get it to overlap with subgid/idmap...
    "net.ipv4.ping_group_range" = "0 7999";
  };
}
