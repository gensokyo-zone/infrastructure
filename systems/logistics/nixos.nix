{
  config,
  meta,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf;
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.sops
    nixos.base
    nixos.barcodebuddy-scanner
    ./hardware-configuration.nix
  ];

  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  networking.networkmanager.enable = true;

  services.xserver.enable = true;
  services.xserver.displayManager.lightdm.enable = true;
  services.xserver.desktopManager.xfce.enable = true;
  programs.firefox.enable = true;

  services.printing.enable = true;

  sound.enable = true;
  hardware.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    #jack.enable = true;
  };

  users.users.logistics = {
    uid = 1000;
    isNormalUser = true;
    description = "Logistics";
    extraGroups = ["networkmanager"];
    hashedPasswordFile = config.sops.secrets.logistics-user-password.path;
  };
  services.barcodebuddy-scanner.user = "logistics";
  services.displayManager.autoLogin = {
    enable = true;
    user = "logistics";
  };

  sops = {
    defaultSopsFile = ./secrets.yaml;
    secrets = {
      logistics-user-password = {
        neededForUsers = true;
      };
      networkmanager-wifi-connection = mkIf config.networking.networkmanager.enable {
        path = "/etc/NetworkManager/system-connections/wifi.nmconnection";
        mode = "0400";
      };
    };
  };

  system.stateVersion = "23.11";
}
