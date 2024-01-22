{
  lib,
  config,
  ...
}: let
  inherit (lib) mkDefault;
  cfg = config.services.kanidm;
in {
  services.kanidm = {
    enableServer = true;
    enableClient = true;
    server = {
      unencrypted.enable = mkDefault true;
      frontend = {
        domain = mkDefault "id.${cfg.serverSettings.domain}";
        address = mkDefault "0.0.0.0";
      };
      ldap = {
        enable = mkDefault true;
        address = mkDefault "0.0.0.0";
      };
    };
    clientSettings = {
      verify_ca = mkDefault true;
      verify_hostnames = mkDefault true;
    };
    serverSettings = {
      role = mkDefault "WriteReplica";
      log_level = mkDefault "info";
    };
  };
}
