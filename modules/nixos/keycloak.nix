{
  config,
  lib,
  ...
}: let
  inherit (lib.options) mkOption;
  inherit (lib.modules) mkOptionDefault;
  cfg = config.services.keycloak;
in {
  options.services.keycloak = with lib.types; {
    protocol = mkOption {
      type = enum ["http" "https"];
      readOnly = true;
    };
    port = mkOption {
      type = port;
      readOnly = true;
    };
  };
  config.services.keycloak = {
    protocol = mkOptionDefault (
      if cfg.sslCertificate != null
      then "https"
      else "http"
    );
    port = mkOptionDefault cfg.settings."${cfg.protocol}-port";
  };
}
