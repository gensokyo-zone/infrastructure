_: {
  services.readarr = {
    enable = true;
  };
  users.users.readarr.extraGroups = [ "kyuuto" ];
}
