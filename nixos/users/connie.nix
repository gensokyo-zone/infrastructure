{ config, ... }:

{
  users.users.connieallure = { name, ... }: {
    uid = 8003;
    isNormalUser = true;
    autoSubUidGidRange = false;
    group = name;
    extraGroups = [ "users" "peeps" "kyuuto" ];
  };
  users.groups.connieallure = { name, ... }: {
    gid = config.users.users.${name}.uid;
  };
}
