{
  config,
  lib,
  ...
}: {
  networking.firewall.allowedTCPPorts = [
    1883
  ];

  sops.secrets = {
    z2m-pass.owner = "mosquitto";
    systemd-pass.owner = "mosquitto";
    hass-pass.owner = "mosquitto";
    espresense-pass.owner = "mosquitto";
  };

  services.mosquitto = {
    enable = true;
    persistence = true;
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
          allow_anonymous = false;
        };
      }
    ];
  };
}
