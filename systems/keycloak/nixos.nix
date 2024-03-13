{meta, ...}: {
  imports = let
    inherit (meta) nixos;
  in [
    #nixos.sops
    nixos.base
    nixos.reisen-ct
    nixos.keycloak
  ];

  #sops.defaultSopsFile = ./secrets.yaml;

  systemd.network.networks.eth0 = {
    name = "eth0";
    matchConfig = {
      MACAddress = "BC:24:11:C4:66:AC";
      Type = "ether";
    };
    address = ["10.1.1.48/24"];
    gateway = ["10.1.1.1"];
    DHCP = "no";
  };

  system.stateVersion = "23.11";
}
