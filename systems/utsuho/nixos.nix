{meta, config, ...}: {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.base
    nixos.reisen-ct
  ];

  systemd.network.networks.eth0 = {
    name = "eth0";
    matchConfig = {
      MACAddress = "BC:24:11:C4:66:A6";
      Type = "ether";
    };
    address = ["10.1.1.38/24"];
    gateway = ["10.1.1.1"];
    DHCP = "no";
  };

  system.stateVersion = "23.11";
}
