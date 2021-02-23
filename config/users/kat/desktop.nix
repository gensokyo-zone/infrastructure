{ config, lib, pkgs, ... }:

let
  sources = import ../../../nix/sources.nix;
  unstable = import sources.nixpkgs-unstable { inherit (pkgs) config; };
in {
  config = lib.mkIf (lib.elem "desktop" config.meta.deploy.profiles) {

    nixpkgs.config = {
      mumble.speechdSupport = true;
      pulseaudio = true;
    };

    services.xserver.enable = true;
    services.xserver.displayManager.lightdm.enable = true;
    programs.light.enable = true;
    services.tumbler.enable = true;
    
    users.users.kat = {
      packages = with pkgs; [
        _1password
        bitwarden
        mpv
        element-desktop
        mumble
        obs-studio
        xfce.ristretto
        avidemux
        vlc
        ffmpeg-full
        thunderbird
        unstable.syncplay
        unstable.youtube-dl
        unstable.google-chrome
        v4l-utils
        transmission-gtk
        jdk11
        lm_sensors
        psmisc
        unstable.discord
        tdesktop
        pinentry.gtk2
        dino
        nextcloud-client
        vegur
        nitrogen
        terminator
        pavucontrol
        appimage-run
        gparted
        scrot
        gimp-with-plugins
        vscode
        cryptsetup
        pcmanfm
        neofetch
        htop
      ];
  };

      programs.gnupg.agent = {
        enable = true;
        enableSSHSupport = true;
        pinentryFlavor = "gtk2";
      };

    home-manager.users.kat = {

      services.nextcloud-client.enable = true;

      programs.firefox = { enable = true; };

      services.kdeconnect = {
        enable = true;
        indicator = true;
      };

      gtk = {
        enable = true;
        iconTheme = {
          name = "Numix-Square";
          package = pkgs.numix-icon-theme-square;
        };
        theme = {
          name = "Arc-Dark";
          package = pkgs.arc-theme;
        };
      };
    };

    services.pcscd.enable = true;
    services.udev.packages = [ pkgs.yubikey-personalization ];

    fonts.fontconfig.enable = true;
    fonts.fonts = [ pkgs.nerdfonts pkgs.corefonts ];

    # KDE Connect
    networking.firewall = {
      allowedTCPPortRanges = [{
        from = 1714;
        to = 1764;
      }];
      allowedUDPPortRanges = [{
        from = 1714;
        to = 1764;
      }];
    };

    sound.enable = true;
    hardware.pulseaudio.enable = true;
    hardware.opengl.enable = true;
    services.xserver.libinput.enable = true;
  };
}
