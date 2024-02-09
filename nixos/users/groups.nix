{
  config,
  lib,
  inputs,
  ...
}: let
  inherit (lib.attrsets) filterAttrs mapAttrsToList;
  inherit (inputs.self.lib.lib) userIs;
in {
  users.groups = {
    peeps = {
      gid = 8128;
    };
    kyuuto = {
      gid = 8129;
    };
    kyuuto-peeps = {
      gid = 8130;
      members = mapAttrsToList (_: user: user.name) (
        filterAttrs (_: user: userIs "peeps" user && userIs "kyuuto" user) config.users.users
      );
    };
  };
  users.users = {
    guest = {
      uid = 8127;
      group = "nogroup";
      isSystemUser = true;
    };
  };
}
