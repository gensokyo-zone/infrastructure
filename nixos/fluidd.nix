{ config, gensokyo-zone, lib, ... }: let
  inherit (gensokyo-zone.lib) domain;
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.fluidd;
in {
  services = {
    fluidd = {
      enable = mkDefault true;
      hostName = mkDefault "print.local.${domain}";
      # TODO: hostName = "@fluidd_internal";
      nginx.locations."/webcam".proxyPass = let
            inherit (config.services.motion.cameras) printercam;
            inherit (printercam.settings) camera_id;
          in "https://kitchen.local.${domain}/${toString camera_id}/stream";
    };
    nginx = mkIf cfg.enable {
      proxied.enable = true;
      virtualHosts.${cfg.hostName} = {
        proxied.enable = true;
        local.denyGlobal = true;
      };
    };
  };
}
