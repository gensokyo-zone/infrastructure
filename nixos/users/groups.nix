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
    steamaccount = {
      gid = 8131;
    };
    beatsaber = {
      gid = 8132;
    };
    editors = {
      gid = 8133;
    };
    nixbuilder = {
      gid = 8134;
      members = mapAttrsToList (_: user: user.name) (
        filterAttrs (_: user: userIs "peeps" user) config.users.users
      );
    };

    admin = {
      gid = 8126;
      members = mapAttrsToList (_: user: user.name) (
        filterAttrs (_: user: userIs "peeps" user && userIs "wheel" user) config.users.users
      );
    };
  };
  users.users = {
    guest = {
      uid = 8127;
      group = "nogroup";
      isSystemUser = true;
    };
    admin = {
      uid = 8126;
      group = "admin";
      isSystemUser = true;
    };
    opl = {
      uid = 8125;
      group = "nogroup";
      isSystemUser = true;
    };
    nixbld = {
      uid = config.users.groups.nixbuilder.gid;
      group = "nixbuilder";
      isSystemUser = true;
    };
  };
}
