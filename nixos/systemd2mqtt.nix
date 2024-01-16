{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.systemd2mqtt;
in {
  services.systemd2mqtt = {
    enable = mkDefault true;
    user = mkDefault "root";
    mqtt = {
      url = mkDefault (if config.services.mosquitto.enable
        then "tcp://localhost:1883"
        else "tcp://mqtt.local.${config.networking.domain}:1883"
      );
      username = mkDefault "systemd";
    };
  };

  systemd.services.systemd2mqtt = mkIf cfg.enable rec {
    requires = mkIf config.services.mosquitto.enable ["mosquitto.service"];
    after = requires;
    serviceConfig.EnvironmentFile = [
      config.sops.secrets.systemd2mqtt-env.path
    ];
  };

  sops.secrets = {
    systemd2mqtt-env = {
      sopsFile = mkDefault ./secrets/systemd2mqtt.yaml;
      owner = cfg.user;
    };
  };
}
