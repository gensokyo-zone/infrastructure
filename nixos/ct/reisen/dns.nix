{
  lib,
  config,
  options,
  meta,
  access,
  ...
}: let
  inherit (lib.modules) mkIf mkBefore mkDefault mkOrder;
  enableDns = !config.services.dnsmasq.enable && config.networking.hostName != "utsuho";
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.avahi
  ];

  networking.nameservers' = mkIf enableDns (mkBefore [
    {address = access.getAddressFor (access.systemForService "dnsmasq").name "lan";}
  ]);
  # prioritize our resolver over systemd-resolved!
  system.nssDatabases.hosts = let
    avahiResolverEnabled = config.services.avahi.enable && (config.services.avahi.nssmdns4 || config.services.avahi.nssmdns4);
  in
    mkIf (enableDns && (config.services.resolved.enable || avahiResolverEnabled)) (mkOrder 475 ["dns"]);
  services.resolved = mkIf enableDns (if options.services.resolved ? "settings" then {
    settings.Resolve.DNSStubListener = mkDefault false;
  } else {
    extraConfig = ''
      DNSStubListener=no
    '';
  });
}
