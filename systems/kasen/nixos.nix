{
  meta,
  config,
  lib,
  pkgs,
  ...
}: let
  inherit (lib.modules) mkForce;
  inherit (config.services) nginx;
in {
  imports = let
    inherit (meta) nixos;
  in [
    #nixos.sops
    nixos.base
    nixos.nginx
  ];

  boot.loader.grub.enable = false;
  boot.loader.generic-extlinux-compatible.enable = true;

  networking.interfaces.enu1u1.useDHCP = true;

  hardware.rtl-sdr.enable = true;

  services.openwebrx = {
    enable = true;
    package = pkgs.openwebrxplus;
  };
  systemd.services.openwebrx.serviceConfig = {
    DynamicUser = mkForce false;
    User = "openwebrx";
    Group = "openwebrx";
  };

  users.users.openwebrx = {
        isSystemUser = true;
        group = "openwebrx";
        extraGroups = [
          "plugdev"
        ];
  };
  users.groups.openwebrx = {};

  networking.firewall.allowedTCPPorts = [
    8073
  ];

  #sops.defaultSopsFile = ./secrets.yaml;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
    fsType = "ext4";
  };

  system.stateVersion = "24.05";
}