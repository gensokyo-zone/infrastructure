{ config, gensokyo-zone, ... }: let
  inherit (config.services) motion;
  inherit (gensokyo-zone.lib) domain;
in {
  services = {
    fluidd = {
      enable = true;
      hostName = "print.local.gensokyo.zone";
      nginx.locations."/webcam".proxyPass = let
            inherit (motion.cameras) printercam;
            inherit (printercam.settings) camera_id;
          in "https://kitchen.local.${domain}/${toString camera_id}/stream";
    };
  };

  networking.firewall.interfaces.lan.allowedTCPPorts = [80];
}
