_: {
  imports = [
  ];
  deploy.hostname = "10.1.1.139";
  # TODO: get an aarch64-linux builder on aya!
  ci.enable = false;
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
