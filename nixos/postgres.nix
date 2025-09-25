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
    ensureDatabases = ["hass" "invidious" "dex" "keycloak" "vaultwarden"];
    ensureUsers = [
      {
        name = "hass";
        ensureDBOwnership = true;
        authentication.int.allow = !config.services.home-assistant.enable;
      }
      {
        name = "invidious";
        ensureDBOwnership = true;
        authentication.int.allow = !config.services.invidious.enable;
      }
      {
        name = "dex";
        ensureDBOwnership = true;
        authentication.local.allow = true;
      }
      {
        name = "keycloak";
        ensureDBOwnership = true;
        authentication.int.allow = !config.services.keycloak.enable;
      }
      {
        name = "vaultwarden";
        ensureDBOwnership = true;
        authentication.int.allow = !config.services.vaultwarden.enable;
      }
    ];
  };
  services.postgresqlBackup = {
    enable = mkDefault cfg.enable;
    compression = mkDefault "none";
    location = mkDefault "/mnt/shared/postgresql/dump";
    startAt = mkDefault "*-*-* 00:30:00";
    databases = [
      #"hass" # only used for recorder (entity state history) module, so just a useless large cache?
      "invidious"
      #"dex"
      "keycloak"
      "vaultwarden"
    ];
  };

  systemd = {
    services.postgresql = mkIf cfg.enable {
      gensokyo-zone.sharedMounts."postgresql/${versions.major cfg.package.version}".path = cfg.dataDir;
      postStart = mkAfter ''
        ''${PSQL-psql} -tAf ${config.sops.secrets.postgresql-init.path}
      '';
    };
  };

  sops.secrets.postgresql-init = {
    sopsFile = mkDefault ./secrets/postgres.yaml;
    owner = "postgres";
    group = "postgres";
  };
}
