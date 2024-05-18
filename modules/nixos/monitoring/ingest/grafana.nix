_: {
  services.grafana = {
    #enable = true;
    settings.server = {
      domain = "gensokyo.zone";
      http_port = 9092;
      http_addr = "0.0.0.0";
      root_url = "https://mon.gensokyo.zone";
    };
  };
}
