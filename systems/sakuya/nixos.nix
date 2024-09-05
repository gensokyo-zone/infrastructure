{
  config,
  meta,
  ...
}: {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.tailscale
  ];
  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
    fsType = "ext4";
  };

  networking.useNetworkd = true;
  systemd.network = {
    networks."40-end0" = {
      inherit (config.systemd.network.links.end0) matchConfig;
      address = ["10.1.1.50/24"];
      gateway = ["10.1.1.1"];
      DHCP = "no";
      networkConfig = {
        IPv6AcceptRA = true;
      };
      linkConfig = {
        Multicast = true;
      };
    };
    links.end0 = {
      matchConfig = {
        Type = "ether";
        MACAddress = "02:ba:46:f8:40:52";
      };
      linkConfig = {
        WakeOnLan = "magic";
      };
    };
  };
  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "24.11";
}
