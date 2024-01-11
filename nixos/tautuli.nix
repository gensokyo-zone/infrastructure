{config, ...}: {
  services = {
    tautulli = {
      enable = true;
      port = 8181;
    };

    nginx.virtualHosts."tautuli.gensokyo.zone" = {
      enableACME = true;
      locations."/".proxyPass = "http://localhost:${toString config.services.tautulli.port}";
    };
  };
}
