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
    nixos.tailscale
    nixos.github-runner.zone
  ];

  nix.gc = {
    dates = "monthly";
    options = "--delete-older-than 30d";
  };

  services.github-runner-zone = {
    count = 16;
    runnerSettings.networkNamespace.name = "ns1";
  };

  networking.namespaces.ns1 = {
    dhcpcd.enable = true;
    nftables = {
      enable = true;
      rejectLocaladdrs = true;
      serviceSettings = rec {
        wants = [ "localaddrs.service" ];
        after = wants;
      };
    };
    interfaces.eth1 = { };
  };
  systemd.network.networks.eth0 = {
    name = "eth0";
    matchConfig = {
      MACAddress = "BC:24:11:C4:66:A9";
      Type = "ether";
    };
    address = ["10.1.1.47/24"];
    gateway = ["10.1.1.1"];
    DHCP = "no";
  };
  systemd.network.networks.eth1 = {
    name = "eth1";
    matchConfig = {
      MACAddress = "BC:24:11:C4:66:AA";
      Type = "ether";
    };
    DHCP = "no";
    slaac.enable = false;
    mdns.enable = false;
  };

  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "23.11";
}
