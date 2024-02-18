{ config, ... }: {
  sops.secrets = {
    invidious_db_password = {
      sopsFile = ./secrets/invidious.yaml;
    };
    invidious_hmac_key = {
      sopsFile = ./secrets/invidious.yaml;
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
