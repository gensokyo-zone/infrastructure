{
  meta,
  config,
  lib,
  modulesPath,
  pkgs,
  ...
}: {
  imports = let
    inherit (meta) nixos;
  in [
    #nixos.sops
    nixos.base
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
      device = "/dev/disk/by-uuid/bf317f5d-ffc2-45fd-9621-b645ff7223fc";
      fsType = "xfs";
    };
    "/boot" = {
      device = "/dev/disk/by-uuid/CA62-7FDF";
      fsType = "vfat";
      options = ["fmask=0077" "dmask=0077"];
    };
  };

  environment.systemPackages = [
    pkgs.ipmitool
  ];

  system.stateVersion = "24.05";
}
