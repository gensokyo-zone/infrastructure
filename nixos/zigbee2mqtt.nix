{
  config,
  lib,
  gensokyo-zone,
  access,
  ...
}: let
  inherit (gensokyo-zone.lib) mkAlmostDefault;
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.zigbee2mqtt;
in {
  sops.secrets.z2m-secret = {
    sopsFile = mkDefault ./secrets/zigbee2mqtt.yaml;
    owner = "zigbee2mqtt";
    path = "${cfg.dataDir}/secret.yaml";
  };

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
        server = let
          utsuho = access.nixosFor "utsuho";
          mqttHost = access.getHostnameFor "utsuho" "lan";
        in mkIf (!config.services.mosquitto.enable) (
          assert utsuho.services.mosquitto.enable; mkAlmostDefault "mqtt://${mqttHost}:1883"
        );
      };
      homeassistant = true;
      permit_join = false;
      frontend = {
        port = 8072;
      };
      serial = {
        port = "/dev/ttyZigbee";
      };
      availability = {
        # minutes
        active.timeout = 10;
        passive.timeout = 60 * 50;
      };
    };
  };

  services.udev.extraRules = mkIf cfg.enable ''
    SUBSYSTEM=="tty", ATTRS{interface}=="Sonoff Zigbee 3.0 USB Dongle Plus", OWNER="zigbee2mqtt", SYMLINK+="ttyZigbee"
  '';

  networking.firewall.interfaces.local.allowedTCPPorts = mkIf cfg.enable [
    cfg.settings.frontend.port
  ];
}
