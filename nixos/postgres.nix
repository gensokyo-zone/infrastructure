{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault mkAfter;
  cfg = config.services.postgresql;
in {
  services.postgresql = {
    enable = mkDefault true;
    ensureDatabases = ["hass" "dex"];
    ensureUsers = [
      {
        name = "hass";
        ensureDBOwnership = true;
        authentication.tailscale.allow = !config.services.home-assistant.enable;
      }
      {
        name = "dex";
        ensureDBOwnership = true;
        authentication.local.allow = true;
      }
    ];
  };

  systemd.services.postgresql = mkIf cfg.enable {
    postStart = mkAfter ''
      $PSQL -tAf ${config.sops.secrets.postgresql-init.path}
    '';
  };

  sops.secrets.postgresql-init = {
    sopsFile = mkDefault ./secrets/postgres.yaml;
    owner = "postgres";
    group = "postgres";
  };
}
