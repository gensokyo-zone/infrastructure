{config, ...}: {
  sops.secrets = let
    commonSecret = {
      sopsFile = ./secrets/keycloak.yaml;
      owner = "keycloak";
    };
  in {
    keycloak_db_password = commonSecret;
  };

  services.keycloak = {
    enable = true;

    database = {
      host = "postgresql.local.${config.networking.domain}";
      passwordFile = config.sops.secrets.keycloak_db_password.path;
      createLocally = false;
    };

    settings = {
        hostname = "sso.gensokyo.zone";
        proxy = "edge";
    };
  };
}
