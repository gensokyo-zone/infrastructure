{
  pkgs,
  config,
  gensokyo-zone,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
  inherit (gensokyo-zone.lib) mkAlmostOptionDefault;
in {
  boot = {
    loader = mkIf (config.nixpkgs.system == "x86_64-linux") {
      systemd-boot.enable = mkAlmostOptionDefault true;
      efi.canTouchEfiVariables = mkAlmostOptionDefault true;
    };
  };

  environment.systemPackages = [
    pkgs.pciutils
    pkgs.usbutils
  ];
}
