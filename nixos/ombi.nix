{config, ...}: {
  services = {
    ombi = {
      enable = true;
      port = 5000;
    };
    nginx.virtualHosts."ombi.gensokyo.zone" = {
      enableACME = true;
      locations."/".proxyPass = "http://localhost:${toString config.services.ombi.port}";
    };
  };
}
