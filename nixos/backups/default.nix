{
  config,
  lib,
  ...
}: let
in {
  users = {
    groups.backups = {
      gid = config.users.users.backups.uid;
    };
    users.backups = {
      uid = 919;
      group = "backups";
    };
  };
}
