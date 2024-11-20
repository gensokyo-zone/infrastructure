_: {
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  network.networks = {
    local = {
      macAddress = "64:00:6a:c0:a1:4c";
      address4 = "10.1.1.60";
    };
  };
}
