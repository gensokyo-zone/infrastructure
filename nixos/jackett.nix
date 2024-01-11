_: {
  services = {
    jackett = {
      enable = true;
    };
    nginx.virtualHosts."jackett.gensokyo.zone" = {
      enableACME = true;
      locations."/".proxyPass = "http://localhost:9117/";
    };
  };
  # Port 9117
}
