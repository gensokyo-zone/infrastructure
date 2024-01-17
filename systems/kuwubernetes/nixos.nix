{
  config,
  meta,
  lib,
  modulesPath,
  ...
}: {
  imports = with meta; [
    (modulesPath + "/profiles/qemu-guest.nix")
    nixos.k3s
  ];

  boot = {
    initrd.availableKernelModules = [
      "ata_piix"
      "uhci_hcd"
      "virtio_pci"
      "virtio_scsi"
      "sd_mod"
      "sr_mod"
    ];
    loader.grub.device = "/dev/sda";
  };

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/5ab5efe2-0250-4bf1-8fd6-3725cdd15031";
    fsType = "ext4";
  };

  swapDevices = [
    {device = "/dev/disk/by-uuid/b374e454-7af5-46fc-b949-24e38a2216d5";}
  ];

  networking.interfaces.ens18.useDHCP = true;

  system.stateVersion = "23.11";
}
