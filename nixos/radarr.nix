_: {
  services.radarr = {
    enable = true;
  };

  users.users.radarr.extraGroups = ["kyuuto"];
}
