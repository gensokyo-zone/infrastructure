{config, lib, ...}: let
  inherit (lib.modules) mkIf mkForce mkDefault;
  inherit (config.lib.access) mkSnakeOil;
  cfg = config.services.keycloak;
  cert = mkSnakeOil {
    name = "keycloak-selfsigned";
    domain = hostname;
  };
  hostname = "sso.${config.networking.domain}";
in {
  sops.secrets = let
    commonSecret = {
      sopsFile = ./secrets/keycloak.yaml;
      owner = "keycloak";
    };
  in {
    keycloak_db_password = commonSecret;
  };
  users = mkIf cfg.enable {
    users.keycloak = {
      isSystemUser = true;
      group = "keycloak";
    };
    groups.keycloak = {
    };
  };

  networking.firewall.interfaces.local.allowedTCPPorts = mkIf cfg.enable [
    (if cfg.sslCertificate != null then 443 else 80)
  ];
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
      hostname = mkDefault hostname;
      proxy = mkDefault (if cfg.sslCertificate != null then "reencrypt" else "edge");
      proxy-headers = mkDefault "xforwarded";
    };

    sslCertificate = mkDefault "${cert}/fullchain.pem";
    sslCertificateKey = mkDefault "${cert}/key.pem";
  };
}
