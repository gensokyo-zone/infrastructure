{config, lib, ...}: let
    inherit (lib.modules) mkForce;
in {
  sops.secrets = let
    commonSecret = {
      sopsFile = ./secrets/keycloak.yaml;
      owner = "keycloak";
    };
  in {
    keycloak_db_password = commonSecret;
  };
users.users.keycloak = {
    isSystemUser = true;
    group = "keycloak";
};

networking.firewall.allowedTCPPorts = [ 80 ];
users.groups.keycloak = {};
systemd.services.keycloak.serviceConfig.DynamicUser = mkForce false;

  services.keycloak = {
    enable = true;

    database = {
      host = "postgresql.local.${config.networking.domain}";
      passwordFile = config.sops.secrets.keycloak_db_password.path;
      createLocally = false;
      useSSL = false;
    };

    settings = {
        hostname = "sso.gensokyo.zone";
        proxy = "edge";
    };
  };
}
