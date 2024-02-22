{
  meta,
  ...
}: {
  imports = let
    inherit (meta) nixos;
  in [
    #nixos.sops
    nixos.base
    nixos.reisen-ct
    nixos.tailscale
    nixos.syncthing-kat
  ];

  #sops.defaultSopsFile = ./secrets.yaml;

  systemd.network.networks.eth0 = {
    name = "eth0";
    matchConfig = {
      MACAddress = "BC:24:11:34:F4:AB";
      Type = "ether";
    };
    DHCP = "yes";
  };

  system.stateVersion = "23.11";
}
