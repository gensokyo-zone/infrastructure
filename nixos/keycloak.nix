{
  access,
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkForce mkDefault;
  cfg = config.services.keycloak;
  cert = access.mkSnakeOil {
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
  in
    mkIf cfg.enable {
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

  networking.firewall.interfaces.lan.allowedTCPPorts = mkIf cfg.enable [
    cfg.port
  ];
  systemd.services.keycloak = mkIf cfg.enable {
    serviceConfig.DynamicUser = mkForce false;
  };

  services.keycloak = {
    enable = true;

    database = let
      system = access.systemForService "postgresql";
      inherit (system.exports.services) postgresql;
    in {
      host = access.getAddressFor system.name "lan";
      port = postgresql.ports.default.port;
      passwordFile = config.sops.secrets.keycloak_db_password.path;
      createLocally = false;
      useSSL = postgresql.ports.default.ssl;
    };

    settings = let
      hostname-strict = false;
    in {
      hostname = mkDefault (
        if cfg.settings.hostname-strict
        then hostname
        else null
      );
      hostname-strict = mkDefault hostname-strict;
      hostname-strict-https = mkDefault hostname-strict;
      proxy-headers = mkDefault "xforwarded";
      http-port = mkDefault 8080;
      https-port = mkDefault 8443;
    };

    sslCertificate = mkDefault "${cert}/fullchain.pem";
    sslCertificateKey = mkDefault "${cert}/key.pem";
  };
}
