{
  config,
  pkgs,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  opengl32 = false;
  opencl = false;
in {
  boot = {
    initrd.availableKernelModules = ["xhci_pci" "nvme" "usb_storage" "sd_mod" "rtsx_pci_sdmmc"];
    kernelModules = ["kvm-intel"];
    extraModulePackages = [];
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/3331f9a0-6b86-411c-8574-63de28046cf2";
    fsType = "ext4";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/8DC2-0DAE";
    fsType = "vfat";
    options = ["fmask=0022" "dmask=0022"];
  };

  swapDevices = [];

  nixpkgs.hostPlatform = "x86_64-linux";
  hardware = {
    enableRedistributableFirmware = true;
    cpu.intel.updateMicrocode = true;
    opengl = {
      extraPackages = [
        pkgs.intel-media-driver
        (mkIf opencl pkgs.intel-compute-runtime)
      ];
      extraPackages32 = mkIf opengl32 [
        pkgs.driversi686Linux.intel-media-driver
      ];
    };
  };
}
