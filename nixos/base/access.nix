{
  config,
  pkgs,
  meta,
  ...
}: {
  security.sudo.wheelNeedsPassword = false;

  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';

  imports = let
    inherit (meta) nixos;
  in [
    nixos.users
  ];

  users.motd = ''
    [0m[1;35m${config.networking.hostName}.${config.networking.domain}[0m

  '';
  users.defaultUserShell = pkgs.zsh;

  users.users.root = {
    hashedPassword = "$6$i28yOXoo$/WokLdKds5ZHtJHcuyGrH2WaDQQk/2Pj0xRGLgS8UcmY2oMv3fw2j/85PRpsJJwCB2GBRYRK5LlvdTleHd3mB.";
    openssh.authorizedKeys.keys = with pkgs.lib;
      (concatLists (mapAttrsToList
        (name: user:
          if elem "wheel" user.extraGroups
          then user.openssh.authorizedKeys.keys
          else [])
        config.users.users));
  };
}
