_: {
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  deploy.hostname = "10.1.1.63";
  exports = {
    services = {
      sshd.enable = true;
    };
  };
}
