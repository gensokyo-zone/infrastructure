{
  config,
  pkgs,
  ...
}: {
  environment.systemPackages = [
    pkgs.ipmitool
  ];

  boot = {
    initrd = {
      availableKernelModules = ["ahci" "xhci_pci" "ehci_pci" "usbhid" "usb_storage" "sd_mod" "sr_mod"];
      kernelModules = [];
    };
    kernelModules = [];
    extraModulePackages = [];
    loader = {
      systemd-boot.enable = true;
      efi.canTouchEfiVariables = true;
    };
  };

  fileSystems = {
    "/" = {
      # TODO
      device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
      fsType = "xfs";
    };
  };

  networking.useNetworkd = true;
  systemd.network = {
    networks."40-eno1" = {
      inherit (config.systemd.network.links.eno1) matchConfig;
      address = ["10.1.1.60/24"];
      gateway = ["10.1.1.1"];
      DHCP = "no";
      networkConfig = {
        IPv6AcceptRA = true;
      };
      linkConfig = {
        Multicast = true;
      };
    };
    links.eno1 = {
      matchConfig = {
        Type = "ether";
        MACAddress = "64:00:6a:c0:a1:4c";
      };
    };
  };
}
