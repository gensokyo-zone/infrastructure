_: {
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  network.networks = {
    local = {
      fqdn = null;
      address4 = null;
      address6 = null;
    };
  };
}
