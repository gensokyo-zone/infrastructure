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
      url = mkIf config.services.mosquitto.enable (
        mkDefault "tcp://localhost:1883"
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
    systemd2mqtt-env.owner = cfg.user;
  };
}
