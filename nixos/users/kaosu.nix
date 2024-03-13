{config, ...}: {
  users.users.kaosubaloo = {name, ...}: {
    uid = 8002;
    isNormalUser = true;
    autoSubUidGidRange = false;
    group = name;
    extraGroups = [
      "users"
      "peeps"
      "kyuuto"
      "steamaccount"
      "beatsaber"
    ];
  };
  users.groups.kaosubaloo = {name, ...}: {
    gid = config.users.users.${name}.uid;
  };
}
