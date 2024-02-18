{ config, ... }: {
  sops.secrets = {
    invidious_db_password = {
      sopsFile = ./secrets/invidious.yaml;
      owner = "invidious";
    };
    invidious_hmac_key = {
      sopsFile = ./secrets/invidious.yaml;
      owner = "invidious";
    };
  };
  services.invidious = {
    enable = true;
    hmacKeyFile = config.sops.secrets.invidious_hmac_key.path;
    settings = {
      domain = "yt.gensokyo.zone";
      hsts = false;
      db = {
        user = "kemal";
        dbname = "invidious";
      };
    };
    database = {
      host = "postgresql.local.gensokyo.zone";
      passwordFile = config.sops.secrets.invidious_db_password.path;
      createLocally = false;
    };
  };
}
