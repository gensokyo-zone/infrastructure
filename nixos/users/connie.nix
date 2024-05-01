{config, options, ...}: {
  config.users = {
    users.connieallure = {name, ...}: {
      uid = 8003;
      isNormalUser = true;
      autoSubUidGidRange = false;
      group = name;
      extraGroups = [
        "users"
        "peeps"
        "kyuuto"
      ];
    };
    groups.connieallure = {name, ...}: {
      gid = config.users.users.${name}.uid;
    };
  };
  config.${if options ? networking.firewall then "networking" else null} = {
    access.peeps.ranges.connieallure = "2604:3d00::/28";
  };
}
