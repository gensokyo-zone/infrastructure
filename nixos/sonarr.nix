_: {
  services.sonarr = {
    enable = true;
  };
  users.users.sonarr.extraGroups = [ "kyuuto" ];
}
