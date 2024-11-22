{
  pkgs,
  config,
  lib,
  ...
}: {
  environment.systemPackages = [
    pkgs.pciutils
    pkgs.usbutils
  ];
}
