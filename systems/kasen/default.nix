_: {
  imports = [
  ];
  deploy.hostname = "10.1.1.139";
  arch = "aarch64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  exports = {
      services = {
        nginx.enable = true;
        sshd.enable = true;
      };
  };
}