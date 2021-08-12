let katUser = { lib }: let
  trustedImport = {
    config.home-manager.users.kat = {
      imports = lib.optional (builtins.pathExists ../../trusted/users/kat) (import ../../trusted/users/kat/home.nix);
    };
  }; userImport = profile: { config, ... }: {
  config.home-manager.users.kat = {
    imports = [
      (./. + "/${profile}")
    ];
  };
}; profileNames = lib.folderList ./. ["base"];
userProfiles = with userProfiles;
  lib.genAttrs profileNames userImport // {
  base = { imports = [ ./nixos.nix (userImport "base") trustedImport ]; };
  server = { imports = [ personal ]; };
  guiFull = { imports = [ gui sway dev media personal ]; };
}; in userProfiles;
in { __functor = self: katUser; isModule = false; }