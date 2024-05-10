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

  networking.firewall.interfaces.local.allowedTCPPorts = [
    8073
  ];

  #sops.defaultSopsFile = ./secrets.yaml;

  fileSystems."/" = {
    device = "/dev/disk/by-uuid/44444444-4444-4444-8888-888888888888";
    fsType = "ext4";
  };

  networking.useNetworkd = true;
  systemd.network = {
    networks."40-enu1u1" = {
      inherit (config.systemd.network.links.enu1u1) matchConfig;
      address = ["10.1.1.49/24"];
      gateway = ["10.1.1.1"];
      DHCP = "no";
      networkConfig = {
        IPv6AcceptRA = true;
      };
      linkConfig = {
        Multicast = true;
      };
    };
    links.enu1u1 = {
      matchConfig = {
        Type = "ether";
        MACAddress = "b8:27:eb:7e:e2:41";
      };
      linkConfig = {
        WakeOnLan = "magic";
      };
    };
  };
  networking.firewall.interfaces.lan = {
    nftables = {
      conditions = config.networking.firewall.interfaces.local.nftables.conditions;
    };
  };

  system.stateVersion = "24.05";
}
