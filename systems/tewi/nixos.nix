{
  meta,
  config,
  lib,
  pkgs,
  modulesPath,
  ...
}: {
  imports = with meta;
    [
      (modulesPath + "/installer/scan/not-detected.nix")
      nixos.sops
      nixos.tailscale
    ];

  services.kanidm.serverSettings.db_fs_type = "zfs";
  services.tailscale.advertiseExitNode = true;
  services.postgresql.package = pkgs.postgresql_14;

  sops.defaultSopsFile = ./secrets.yaml;

  networking = {
    useNetworkd = true;
    useDHCP = false;
  };
  services.resolved.enable = true;

  boot = {
    loader = {
      systemd-boot = {
        enable = true;
      };
      efi = {
        canTouchEfiVariables = true;
      };
    };
    initrd = {
      availableKernelModules = ["xhci_pci" "ehci_pci" "ahci" "usbhid" "usb_storage" "sd_mod"];
    };
    kernelModules = ["kvm-intel"];
  };

  fileSystems = {
    "/" = {
      device = "/dev/disk/by-uuid/6c5d82b1-5d11-4c72-96c6-5f90e6ce57f5";
      fsType = "ext4";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/85DC-72FA";
      fsType = "vfat";
    };
  };
  systemd = {
    network = {
      networks.eno1 = {
        inherit (config.systemd.network.links.eno1) matchConfig;
        networkConfig = {
          DHCP = "yes";
          DNSDefaultRoute = true;
          MulticastDNS = true;
        };
        linkConfig.Multicast = true;
      };
      links.eno1 = {
        matchConfig = {
          Type = "ether";
          Driver = "e1000e";
        };
        linkConfig = {
          WakeOnLan = "magic";
        };
      };
    };
  };

  swapDevices = lib.singleton {
    device = "/dev/disk/by-uuid/137605d3-5e3f-47c8-8070-6783ce651932";
  };

  system.stateVersion = "21.05";
}
