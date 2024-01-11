{config, ...}: {
  services = {
    bazarr = {
      enable = true;
      listenPort = 6767;
    };

    nginx.virtualHosts."bazarr.gensokyo.zone" = {
      enableACME = true;
      locations."/".proxyPass = "http://localhost:${toString config.services.bazarr.listenPort}";
    };
  };
}
