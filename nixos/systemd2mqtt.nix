{
  config,
  access,
  lib,
  inputs,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.systemd2mqtt;
in {
  imports = [inputs.systemd2mqtt.nixosModules.default];

  services.systemd2mqtt = {
    enable = mkDefault true;
    user = mkDefault "root";
    mqtt = {
      url = mkDefault (
        if config.services.mosquitto.enable
        then "tcp://localhost:1883"
        else
          access.proxyUrlFor {
            serviceName = "mosquitto";
            scheme = "tcp";
          }
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
