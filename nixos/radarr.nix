_: {
  services = {
    radarr = {
      enable = true;
    };
    nginx.virtualHosts."radarr.gensokyo.zone" = {
      enableACME = true;
      locations."/".proxyPass = "http://localhost:7878";
    };
  };

  # Port 7878
}
