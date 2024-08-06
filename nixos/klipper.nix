{ pkgs, ... }: {

  services = {
    klipper = {
      enable = true;
      octoprintIntegration = true;
      mutableConfig = true;
      configFile = "/var/lib/printer.cfg";
    };
  };
}
