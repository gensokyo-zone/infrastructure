{ config, ... }: {
  services.syncthing = {
    enable = true;
    relay.enable = true;
    settings = {
      options = {
      };
      folders = {
      };
    };
  };
}
