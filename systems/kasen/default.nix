_: {
  imports = [
  ];
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
  network.networks = {
    local = {
      macAddress = "b8:27:eb:7e:e2:41";
      address4 = "10.1.1.49";
    };
  };
}
