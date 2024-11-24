_: {
  imports = [
  ];
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  exports = {
    services = {
    };
  };
  network.networks = {
    local = {
      macAddress = "54:48:10:f3:fe:aa";
      address4 = "10.1.1.61";
    };
  };
}
