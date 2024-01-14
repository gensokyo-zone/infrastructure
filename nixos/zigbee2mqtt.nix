{
  config,
  lib,
  ...
}: let
  cfg = config.services.zigbee2mqtt;
  inherit (lib) mkDefault;
in {
  sops.secrets.z2m-secret = {
    owner = "zigbee2mqtt";
    path = "${cfg.dataDir}/secret.yaml";
  };

  users.groups.input.members = [ "zigbee2mqtt" ];

  services.zigbee2mqtt = {
    enable = mkDefault true;
    domain = mkDefault "z2m.${config.networking.domain}";
    settings = {
      advanced = {
        log_level = "info";
        network_key = "!secret network_key";
      };
      mqtt = {
        user = "z2m";
        password = "!secret z2m_pass";
      };
      homeassistant = true;
      permit_join = false;
      frontend = {
        port = 8072;
      };
      serial = {
        port = "/dev/ttyUSB0";
      };
      availability = {
        # minutes
        active.timeout = 10;
        passive.timeout = 60 * 50;
      };
    };
  };
}