{
  meta,
  ...
}: {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.base
    nixos.reisen-ct
  ];

  systemd.network.networks.eth0 = {
    name = "eth0";
    matchConfig = {
      MACAddress = "BC:24:11:C4:66:A8";
      Type = "ether";
    };
    DHCP = "no";
  };

  system.stateVersion = "23.11";
}
