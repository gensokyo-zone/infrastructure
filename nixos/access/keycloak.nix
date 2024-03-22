{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.keycloak;
  inherit (config) networking;
  inherit (config.services) nginx;
  access = nginx.access.keycloak;
  locations = {
    "/" = {
      proxyPass = mkDefault access.url;
    };
  };
in {
  options.services.nginx.access.keycloak = with lib.types; {
    host = mkOption {
      type = str;
      default = "keycloak.local.${networking.domain}";
    };
    url = mkOption {
      type = str;
      default = "https://${access.host}";
    };
  };
  config.services.nginx = {
    access.keycloak = mkIf cfg.enable {
      host = mkDefault "localhost";
      url = mkDefault (if cfg.sslCertificate != null then "https://${access.host}" else "http://${access.host}");
    };
    virtualHosts = {
      keycloak = {
        name.shortServer = mkDefault "sso";
        ssl.force = mkDefault true;
        inherit locations;
      };
      keycloak'local = {
        name.shortServer = mkDefault "sso";
        ssl = {
          force = mkDefault true;
          cert.copyFromVhost = "keycloak";
        };
        local.enable = true;
        inherit locations;
        extraConfig = mkIf false ''
          set $vouch_local_url ${nginx.vouch.localUrl};
          #if ($x_forwarded_host ~ "\.tail\.${networking.domain}$") {
          #  set $vouch_local_url $x_scheme://${nginx.vouch.tailDomain};
          #}
          proxy_redirect ${nginx.vouch.url}/ $vouch_local_url/;
        '';
      };
    };
  };
}
