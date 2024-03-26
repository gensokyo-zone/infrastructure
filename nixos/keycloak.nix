{inputs, system, config, lib, ...}: let
  inherit (lib.modules) mkIf mkForce mkDefault;
  inherit (lib.lists) optional;
  inherit (config.lib.access) mkSnakeOil;
  cfg = config.services.keycloak;
  cert = mkSnakeOil {
    name = "keycloak-selfsigned";
    domain = hostname;
  };
  hostname = "sso.${config.networking.domain}";
  hostname-strict = false;
  inherit (inputs.self.legacyPackages.${system.system}) patchedNixpkgs;
  keycloakModulePath = "services/web-apps/keycloak.nix";
in {
  # upstream keycloak makes an incorrect assumption in its assertions, so we patch it
  disabledModules = optional (!hostname-strict) keycloakModulePath;
  imports = optional (!hostname-strict) (patchedNixpkgs + "/nixos/modules/${keycloakModulePath}");

  sops.secrets = let
    commonSecret = {
      sopsFile = ./secrets/keycloak.yaml;
      owner = "keycloak";
    };
  in mkIf cfg.enable {
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

  networking.firewall.interfaces.int.allowedTCPPorts = mkIf cfg.enable [
    (if cfg.sslCertificate != null then cfg.settings.https-port else cfg.settings.http-port)
  ];
  systemd.services.keycloak = mkIf cfg.enable {
    serviceConfig.DynamicUser = mkForce false;
  };

  services.keycloak = {
    enable = true;

    database = {
      host = "postgresql.int.${config.networking.domain}";
      passwordFile = config.sops.secrets.keycloak_db_password.path;
      createLocally = false;
      useSSL = false;
    };

    settings = {
      hostname = mkDefault (if hostname-strict then hostname else null);
      proxy = mkDefault (if cfg.sslCertificate != null then "reencrypt" else "edge");
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
