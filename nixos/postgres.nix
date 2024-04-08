{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault mkAfter;
  inherit (lib) versions;
  cfg = config.services.postgresql;
in {
  services.postgresql = {
    enable = mkDefault true;
    ensureDatabases = ["hass" "invidious" "dex" "keycloak"];
    ensureUsers = [
      {
        name = "hass";
        ensureDBOwnership = true;
        authentication.int.allow = !config.services.home-assistant.enable;
      }
      {
        name = "invidious";
        ensureDBOwnership = true;
        authentication.int.allow = true;
      }
      {
        name = "dex";
        ensureDBOwnership = true;
        authentication.local.allow = true;
      }
      {
        name = "keycloak";
        ensureDBOwnership = true;
        authentication.int.allow = true;
      }
    ];
  };

  systemd = {
    services.postgresql = mkIf cfg.enable {
      gensokyo-zone.sharedMounts."postgresql/${versions.major cfg.package.version}".path = cfg.dataDir;
      postStart = mkAfter ''
        $PSQL -tAf ${config.sops.secrets.postgresql-init.path}
      '';
    };
  };

  sops.secrets.postgresql-init = {
    sopsFile = mkDefault ./secrets/postgres.yaml;
    owner = "postgres";
    group = "postgres";
  };
}
