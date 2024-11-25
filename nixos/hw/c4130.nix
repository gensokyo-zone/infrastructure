{
  pkgs,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkMerge;
  enableBridge = true;
in {
  imports = [
    ./headless.nix
    ./metal.nix
  ];

  boot = {
    initrd = {
      systemd.network = let
        inherit (config.systemd) network;
      in mkIf config.networking.useNetworkd {
        networks = {
          "10-eno1" = {
            inherit (config.boot.initrd.systemd.network.links."10-eno1") matchConfig;
            inherit (network.networks."10-eno1") address gateway DHCP networkConfig linkConfig;
          };
        };
        links."10-eno1" = {
          matchConfig = {
            inherit (network.links."10-eno1".matchConfig) Type MACAddress;
          };
        };
      };
      availableKernelModules = mkMerge [
        ["ahci" "xhci_pci" "ehci_pci" "usbhid" "usb_storage" "sd_mod" "sr_mod"]
        (mkIf config.boot.initrd.network.enable ["igb"])
      ];
    };
  };

  systemd.network = let
    inherit (config.systemd) network;
  in {
    networks = {
      "10-br" = mkIf enableBridge {
        matchConfig.Name = "br";
        DHCP = "no";
        linkConfig = {
          RequiredForOnline = false;
          Multicast = true;
        };
        networkConfig = {
          IPv6AcceptRA = false;
          MulticastDNS = true;
        };
      };
      "10-eno2" = {
        inherit (network.links."10-eno2") matchConfig;
        bridge = mkIf enableBridge ["br"];
        linkConfig = {
          RequiredForOnline = false;
          #ActivationPolicy = mkIf (!enableBridge) "manual";
        };
      };
    };
    netdevs = {
      br = mkIf enableBridge {
        netdevConfig = {
          Name = "br";
          Kind = "bridge";
          inherit (network.links."10-eno2".matchConfig) MACAddress;
        };
      };
    };
  };

  environment.systemPackages = [
    pkgs.ipmitool
  ];
}
