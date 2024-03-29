{meta, ...}: {
  imports = with meta; [
    nixos.reisen-ct
  ];

  # allow proxmox to provide us with our hostname
  environment.etc.hostname.enable = false;
  services.avahi.hostName = "";

  system.stateVersion = "23.11";
  environment.etc."systemd/network/eth9.network.d/int.conf".text = ''
    [Match]
    Name=eth9
    Type=ether

    [Link]
    RequiredForOnline=false

    [Network]
    IPv6AcceptRA=true
    IPv6SendRA=false
    DHCP=no

    [IPv6Prefix]
    AddressAutoconfiguration=false
    Prefix=fd0c::/64
    Assign=true

    [IPv6AcceptRA]
    DHCPv6Client=false
  '';
}
