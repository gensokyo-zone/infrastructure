{config, lib, ...}: let
  inherit (lib.modules) mkIf;
  cfg = config.services.tautulli;
in {
  services = {
    tautulli = {
      enable = true;
      openFirewall = true;
      port = 8181;
    };

    nginx.virtualHosts = {
      "tautulli.${config.networking.domain}" = {
        locations."/".proxyPass = "http://localhost:${toString cfg.port}";
      };
      "tautulli.local.${config.networking.domain}" = mkIf cfg.openFirewall {
        locations."/".proxyPass = "http://localhost:${toString cfg.port}";
      };
    };
  };
}
