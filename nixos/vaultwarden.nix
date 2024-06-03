{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  inherit (config.services) postgresql;
  cfg = config.services.vaultwarden;
  enableAdmin = false;
in {
  config.services.vaultwarden = {
    enable = mkDefault true;
    dbBackend = mkDefault "postgresql";
    websocketPort = mkDefault 8223;
    databaseUrlPath = mkIf (!postgresql.enable) (mkDefault config.sops.secrets.vaultwarden-database-url.path);
    adminTokenPath = mkIf enableAdmin (mkDefault config.sops.secrets.vaultwarden-admin-token.path);
    config = {
      DOMAIN = mkDefault "https://bw.${config.networking.domain}";
      SIGNUPS_ALLOWED = mkDefault false;
      ROCKET_ADDRESS = mkDefault "::";
      WEBSOCKET_ADDRESS = mkDefault "::";
      DATABASE_URL = mkIf postgresql.enable (mkDefault "postgresql://vaultwarden@/vaultwarden");
    };
  };
  config.systemd.services.vaultwarden = mkIf cfg.enable {
    gensokyo-zone.sharedMounts.vaultwarden.path = mkDefault cfg.config.DATA_FOLDER;
  };
  config.users = mkIf cfg.enable {
    users.vaultwarden.uid = 915;
    groups.vaultwarden.gid = config.users.users.vaultwarden.uid;
  };
  config.networking.firewall = mkIf cfg.enable {
    interfaces.lan.allowedTCPPorts = [
      cfg.port
      (mkIf (cfg.websocketPort != null) cfg.websocketPort)
    ];
  };
  config.sops.secrets = let
    sopsFile = mkDefault ./secrets/vaultwarden.yaml;
    owner = "vaultwarden";
  in {
    vaultwarden-database-url = mkIf (!postgresql.enable) {
      inherit sopsFile owner;
    };
    vaultwarden-admin-token = mkIf enableAdmin {
      inherit sopsFile owner;
    };
  };
}
