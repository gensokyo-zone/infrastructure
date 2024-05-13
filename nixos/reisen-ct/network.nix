{
  lib,
  gensokyo-zone,
  config,
  options,
  meta,
  access,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
  inherit (lib.modules) mkIf mkBefore mkOrder;
  enableDns = !config.services.dnsmasq.enable && config.networking.hostName != "utsuho";
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.avahi
  ];

  #services.resolved.enable = mkIf enableDns false;
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
  networking.nameservers' = mkIf enableDns (mkBefore [
    {address = access.getAddressFor (access.systemForService "dnsmasq").name "lan";}
  ]);
  # prioritize our resolver over systemd-resolved!
  system.nssDatabases.hosts = let
    avahiResolverEnabled = config.services.avahi.enable && (config.services.avahi.nssmdns4 || config.services.avahi.nssmdns4);
  in
    mkIf (enableDns && (config.services.resolved.enable || avahiResolverEnabled)) (mkOrder 475 ["dns"]);
  services.resolved.extraConfig = mkIf enableDns ''
    DNSStubListener=no
  '';

  boot.kernel.sysctl = {
    # not sure how to get it to overlap with subgid/idmap...
    "net.ipv4.ping_group_range" = "0 7999";
  };
}
