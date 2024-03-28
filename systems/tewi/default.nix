_: {
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  network.networks = {
    local = {
      address4 = null;
      address6 = "fd0a::eea8:6bff:fefe:3986";
    };
    tail = {
      address4 = "100.88.107.41";
      address6 = "fd7a:115c:a1e0:ab12:4843:cd96:6258:6b29";
    };
  };
}
