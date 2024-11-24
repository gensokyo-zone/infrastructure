{
  config,
  pkgs,
  meta,
  lib,
  ...
}: let
  inherit (lib.modules) mkIf mkDefault;
in {
  imports = let
    inherit (meta) nixos;
  in [
    nixos.users
  ];

  security.sudo.wheelNeedsPassword = mkDefault false;

  security.polkit.extraConfig = mkIf (!config.security.sudo.wheelNeedsPassword) ''
    polkit.addRule(function(action, subject) {
      if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  users.motd = ''
    [0m[1;35m${config.networking.hostName}.${config.networking.domain}[0m

  '';
  users.defaultUserShell = pkgs.zsh;

  users.users.root = {
    hashedPassword = mkDefault "$6$SLue7utn4qXtW1TE$yQOliCPKgkiFST5H6iqCCwT2dn3o4e/h39MaCbhOXVreFQrkWe7ZzJUOzC0u28/0.Hzs6xKSiJnGjbLXvGstr1";
    openssh.authorizedKeys.keys = with pkgs.lib; (concatLists (mapAttrsToList
      (name: user:
        if elem "wheel" user.extraGroups
        then user.openssh.authorizedKeys.keys
        else [])
      config.users.users));
  };
}
