{
  config,
  lib,
  access,
  ...
}: let
  inherit (lib.modules) mkDefault;
  cfg = config.services.keycloak;
  inherit (config.services) nginx;
in {
  config.services.nginx = {
    virtualHosts = {
      keycloak = {
        name.shortServer = mkDefault "sso";
        ssl.force = mkDefault true;
        locations."/".proxyPass = let
          url = mkDefault "${cfg.protocol}://localhost:${toString cfg.port}";
        in mkDefault (
          if cfg.enable then url
          else access.proxyUrlFor { serviceName = "keycloak"; portName = "https"; }
        );
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
