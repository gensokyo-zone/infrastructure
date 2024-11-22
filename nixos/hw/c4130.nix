{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge mkDefault;
in {
  imports = [
    ./metal.nix
  ];

  boot = {
    loader = {
      systemd-boot.enable = mkDefault true;
    };
    initrd = {
      systemd.network = mkIf config.networking.useNetworkd {
        networks."40-eno1" = {
          inherit (config.boot.initrd.systemd.network.links.eno1) matchConfig;
          inherit (config.systemd.network.networks."40-eno1") address gateway DHCP networkConfig linkConfig;
        };
        links.eno1 = {
          matchConfig = {
            inherit (config.systemd.network.links.eno1.matchConfig) Type MACAddress;
          };
        };
      };
      availableKernelModules = mkMerge [
        ["ahci" "xhci_pci" "ehci_pci" "usbhid" "usb_storage" "sd_mod" "sr_mod"]
        (mkIf config.boot.initrd.network.enable ["igb"])
      ];
    };
  };

  environment.systemPackages = [
    pkgs.ipmitool
  ];
}
