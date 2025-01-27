{
  meta,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.hw.sbc
    nixos.base
    nixos.tailscale
    nixos.nginx
    nixos.openwebrx
    nixos.rtl_tcp
  ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  hardware.rtl-sdr.enable = true;
  services.openwebrx.hardwareDev = mkIf config.services.rtl_tcp.enable null;

  sops.defaultSopsFile = ./secrets.yaml;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
    fsType = "ext4";
  };
  swapDevices = [
    {
      device = "/swap0";
      size = 4096;
    }
  ];

  networking.useNetworkd = true;
  systemd.network = {
    networks."40-enu1u1" = {
      inherit (config.systemd.network.links.enu1u1) matchConfig;
      address = ["10.1.1.49/24"];
      gateway = ["10.1.1.1"];
      DHCP = "no";
      networkConfig = {
        IPv6AcceptRA = true;
      };
      linkConfig = {
        Multicast = true;
      };
    };
    links.enu1u1 = {
      matchConfig = {
        Type = "ether";
        MACAddress = "b8:27:eb:7e:e2:41";
      };
      linkConfig = {
        WakeOnLan = "magic";
      };
    };
  };

  system.stateVersion = "24.05";
}
