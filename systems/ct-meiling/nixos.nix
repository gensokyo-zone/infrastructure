{meta, lib, ...}: {
  imports = with meta; [
    nixos.ct.meiling
  ];

  # allow proxmox to provide us with our hostname
  environment.etc.hostname.enable = false;
  services.avahi.hostName = "";

  system = {
    stateVersion = "25.05";
    nixos.tags = lib.mkForce [ "template" ];
  };
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
    Prefix=fd0c:0:0:2::/64
    Assign=true

    [IPv6AcceptRA]
    DHCPv6Client=false
  '';
}
