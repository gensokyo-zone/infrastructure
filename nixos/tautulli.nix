{config, ...}: {
  services = {
    tautulli = {
      enable = true;
      port = 8181;
    };

    nginx.virtualHosts."tautulli.gensokyo.zone" = {
      locations."/".proxyPass = "http://localhost:${toString config.services.tautulli.port}";
    };
  };
}
