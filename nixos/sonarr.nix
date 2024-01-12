_: {
  services = {
    sonarr = {
      enable = true;
    };

    nginx.virtualHosts."sonarr.gensokyo.zone" = {
      locations."/".proxyPass = "http://localhost:8989";
    };
  };

  # Port 8989
}
