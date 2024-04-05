{
  extern'test'inputs,
  ...
}: let
  inherit (extern'test'inputs.self) nixosModules;
in {
  imports = [
    nixosModules.default
    extern'test'inputs.sops-nix.nixosModules.sops
  ];

  config = {
    gensokyo-zone = {
      access = {
        #tail.enable = true;
        #local.enable = true;
      };
      nix = {
        enable = true;
        builder.enable = true;
      };
      kyuuto = {
        enable = true;
        shared.enable = true;
      };
      krb5 = {
        enable = true;
        sssd.enable = true;
        nfs.enable = true;
      };
      # TODO: users?
    };

    # this isn't a real machine...
    boot.isContainer = true;
    system.stateVersion = "23.11";
    networking.domain = "testing.123";

    sops = {
      age.sshKeyPaths = ["/etc/ssh/ssh_host_ed25519_key"];
    };
  };
}
