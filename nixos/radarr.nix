_: {
  services = {
    radarr = {
      enable = true;
    };
    nginx.virtualHosts."radarr.gensokyo.zone" = {
      locations."/".proxyPass = "http://localhost:7878";
    };
  };

  # Port 7878
}
