{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.keycloak;
  inherit (config.services) nginx;
in {
  config.services.nginx = {
    virtualHosts = {
      keycloak = {
        name.shortServer = mkDefault "sso";
        ssl.force = mkDefault true;
        locations."/".proxyPass = let
          url = mkDefault (if cfg.sslCertificate != null
            then "https://localhost:${toString cfg.settings.https-port}"
            else "http://localhost:${toString cfg.settings.http-port}"
          );
        in mkIf cfg.enable (mkDefault url);
      };
      keycloak'local = {
        name.shortServer = mkDefault "sso";
        ssl = {
          force = mkDefault true;
          cert.copyFromVhost = "keycloak";
        };
        local.enable = true;
        locations."/".proxyPass = mkDefault nginx.virtualHosts.keycloak.locations."/".proxyPass;
      };
    };
  };
}
