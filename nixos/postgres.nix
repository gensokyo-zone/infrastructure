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
    ensureDatabases = ["hass"];
    ensureUsers = [
      {
        name = "hass";
        ensureDBOwnership = true;
        tailscale.allow = !config.services.home-assistant.enable;
      }
    ];
  };

  systemd.services.postgresql = mkIf cfg.enable {
    postStart = mkAfter ''
      $PSQL -tAf ${config.sops.secrets.postgresql-init.path}
    '';
  };

  sops.secrets.postgresql-init = {
    owner = "postgres";
    group = "postgres";
  };
}
