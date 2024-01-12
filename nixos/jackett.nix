_: {
  services = {
    jackett = {
      enable = true;
    };
    nginx.virtualHosts."jackett.gensokyo.zone" = {
      locations."/".proxyPass = "http://localhost:9117/";
    };
  };
  # Port 9117
}
