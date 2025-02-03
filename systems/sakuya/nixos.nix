{
  pkgs,
  config,
  modulesPath,
  meta,
  ...
}: {
  imports = let
    inherit (meta) nixos;
  in [
    (modulesPath + "/installer/sd-card/sd-image.nix")
    nixos.base
    nixos.hw.sbc
    nixos.sops
    nixos.tailscale
    nixos.klipper
    nixos.motion
    nixos.cameras.printer
  ];

  services.motion.cameras.printercam.settings = {
    # TODO: try to limit CPU usage for now...
    width = 1280;
    height = 720;
    framerate = 2;
    text_right = "";
    stream_quality = 60;
  };

  boot.loader = {
    grub.enable = false;
    generic-extlinux-compatible.enable = true;
  };
  sdImage = let
    # TODO: boot0 requires additional BSL processing applied to the uboot bin:
    # https://github.com/longsleep/build-pine64-image/tree/master/u-boot-postprocess
    uboot = pkgs.ubootPine64;
    # Arch Linux ARM has already done this for us...
    ubootPrepackagedARM = pkgs.fetchurl {
      url = "http://os.archlinuxarm.org/os/allwinner/boot/pine64/u-boot-sunxi-with-spl.bin";
      sha256 = "sha256-qT5M93p/t7eW6lqZq4dC8z8BkYcQOkTgiN+jZatObuo=";
    };
    ubootProcessed = ubootPrepackagedARM;
  in {
    postBuildCommands = ''
      dd conv=notrunc if=${ubootProcessed} of=$img bs=8k seek=1
    '';
    # taken from sd-image-aarch64.nix
    populateFirmwareCommands = let
      configTxt = pkgs.writeText "config.txt" ''
        [all]
        # Boot in 64-bit mode.
        arm_64bit=1

        # U-Boot needs this to work, regardless of whether UART is actually used or not.
        # Look in arch/arm/mach-bcm283x/Kconfig in the U-Boot tree to see if this is still
        # a requirement in the future.
        enable_uart=1

        # Prevent the firmware from smashing the framebuffer setup done by the mainline kernel
        # when attempting to show low-voltage or overtemperature warnings.
        avoid_warnings=1
      '';
    in ''
      cp ${configTxt} firmware/config.txt
    '';
    populateRootCommands = ''
      mkdir -p ./files/boot
      ${config.boot.loader.generic-extlinux-compatible.populateCmd} -c ${config.system.build.toplevel} -d ./files/boot
    '';
  };

  fileSystems."/" = {
    device = "/dev/disk/by-label/NIXOS_SD";
    fsType = "ext4";
  };
  swapDevices = [
    {
      device = "/swap0";
      size = 4096;
    }
  ];

  networking.useNetworkd = true;
  systemd.network = {
    networks."40-end0" = {
      inherit (config.systemd.network.links.end0) matchConfig;
      address = ["10.1.1.50/24"];
      gateway = ["10.1.1.1"];
      DHCP = "no";
      networkConfig = {
        IPv6AcceptRA = true;
      };
      linkConfig = {
        Multicast = true;
      };
    };
    links.end0 = {
      matchConfig = {
        Type = "ether";
        MACAddress = "02:ba:46:f8:40:52";
      };
      linkConfig = {
        WakeOnLan = "magic";
      };
    };
  };
  sops.defaultSopsFile = ./secrets.yaml;

  system.stateVersion = "24.11";
}
