{ pkgs, ... }: {

  services = {
    klipper = {
      enable = true;
      octoprintIntegration = true;
      mutableConfig = true;
      mutableConfigFolder = "/var/lib/moonraker/config";
      settings = {};
    };
  };
}
