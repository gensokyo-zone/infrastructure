{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault mkForce;
  cfg = config.services.invidious;
in {
  sops.secrets = let
    commonSecret = {
      sopsFile = ./secrets/invidious.yaml;
      owner = "invidious";
    };
  in {
    invidious_db_password = commonSecret;
    invidious_hmac_key = commonSecret;
  };

  networking.firewall.interfaces.local.allowedTCPPorts = [cfg.port];
  users.groups.invidious = {};
  users.users.invidious = {
    isSystemUser = true;
    group = "invidious";
  };
  systemd.services.invidious.serviceConfig = {
    DynamicUser = mkForce false;
    User = "invidious";
  };
  services.invidious = {
    enable = mkDefault true;
    address = mkIf config.networking.enableIPv6 (mkDefault "::");
    hmacKeyFile = config.sops.secrets.invidious_hmac_key.path;
    settings = {
      domain = "yt.${config.networking.domain}";
      external_port = 443;
      hsts = false;
      db = {
        user = "invidious";
        dbname = "invidious";
      };
    };
    database = {
      host = "postgresql.int.${config.networking.domain}";
      passwordFile = config.sops.secrets.invidious_db_password.path;
      createLocally = false;
    };
  };
}
