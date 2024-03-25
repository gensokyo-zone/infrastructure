{
  config,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
  cfg = config.services.mosquitto;
  sopsFile = mkDefault ./secrets/mosquitto.yaml;
in {
  sops.secrets = {
    z2m-pass = {
      inherit sopsFile;
      owner = "mosquitto";
    };
    systemd-pass = {
      inherit sopsFile;
      owner = "mosquitto";
    };
    hass-pass = {
      inherit sopsFile;
      owner = "mosquitto";
    };
    espresense-pass = {
      inherit sopsFile;
      owner = "mosquitto";
    };
  };

  services.mosquitto = {
    enable = mkDefault true;
    persistence = mkDefault true;
    listeners = [
      {
        acl = [
          "pattern readwrite #"
        ];
        users = {
          z2m = {
            passwordFile = config.sops.secrets.z2m-pass.path;
            acl = [
              "readwrite #"
            ];
          };
          espresense = {
            passwordFile = config.sops.secrets.espresense-pass.path;
            acl = [
              "readwrite #"
            ];
          };
          systemd = {
            passwordFile = config.sops.secrets.systemd-pass.path;
            acl = [
              "readwrite #"
            ];
          };
          hass = {
            passwordFile = config.sops.secrets.hass-pass.path;
            acl = [
              "readwrite #"
            ];
          };
        };
        settings = {
          allow_anonymous = mkDefault false;
        };
      }
    ];
    settings = {
      autosave_interval = mkDefault 120;
    };
  };
  systemd.services.mosquitto = mkIf cfg.enable {
    serviceConfig.BindPaths = [
      "/mnt/shared/mosquitto:${cfg.dataDir}"
    ];
  };
}
