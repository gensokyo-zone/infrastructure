_: {
  services = {
    moonraker = {
      enable = true;
      address = "0.0.0.0";
      settings = {
        octoprint_compat = { };
        history = { };
        authorization = {
          force_logins = true;
          cors_domains = [
            "*.local"
            "*.lan"
            "*.gensokyo.zone"
          ];
          trusted_clients = [
            "10.0.0.0/8"
            "127.0.0.0/8"
            "::1/128"
          ];
        };
      };
    };
  };
}
