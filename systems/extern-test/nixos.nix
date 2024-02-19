{
  extern'test'inputs,
  ...
}: let
  inherit (extern'test'inputs.self) nixosModules;
in {
  imports = [
    nixosModules.default
  ];

  config = {
    gensokyo-zone = {
      nix = {
        enable = true;
        builder.enable = true;
      };
      kyuuto = {
        enable = true;
        shared.enable = true;
      };
      # TODO: users?
    };

    # this isn't a real machine...
    boot.isContainer = true;
    system.stateVersion = "23.11";
  };
}
