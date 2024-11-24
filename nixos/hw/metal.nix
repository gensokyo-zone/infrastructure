{
  pkgs,
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
in {
  boot = {
    loader = {
      systemd-boot.enable = mkAlmostOptionDefault true;
      efi.canTouchEfiVariables = mkAlmostOptionDefault true;
    };
  };

  environment.systemPackages = [
    pkgs.pciutils
    pkgs.usbutils
  ];
}
