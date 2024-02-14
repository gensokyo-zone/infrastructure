{
  meta,
  ...
}: {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.base
    nixos.reisen-ct
    nixos.kyuuto
    nixos.steam.account-switch
    nixos.steam.beatsaber
    nixos.tailscale
    nixos.nfs
  ];

  kyuuto.setup = true;
  services.steam = {
    accountSwitch.enable = false;
    beatsaber.enable = false;
  };

  proxmoxLXC.privileged = true;

  systemd.network.networks.eth0 = {
    name = "eth0";
    matchConfig = {
      MACAddress = "BC:24:11:C4:66:A8";
      Type = "ether";
    };
    address = ["10.1.1.45/24"];
    gateway = ["10.1.1.1"];
    DHCP = "no";
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
