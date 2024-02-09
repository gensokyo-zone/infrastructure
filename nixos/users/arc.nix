{ config, ... }:

{
  users.users.arc = { name, ... }: {
    uid = 8001;
    isNormalUser = true;
    autoSubUidGidRange = false;
    group = name;
    extraGroups = [ "users" "peeps" "kyuuto" "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJ8Z6briIboxIdedPGObEWB6QEQkvxKvnMW/UVU9t/ac mew-pgp"
    ];
  };
  users.groups.arc = { name, ... }: {
    gid = config.users.users.${name}.uid;
  };
}
