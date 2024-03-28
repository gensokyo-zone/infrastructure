_: {
  imports = [
    ./proxmox.nix
  ];
  arch = "x86_64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  network.networks = {
    tail = {
      address4 = "100.71.65.59";
      address6 = "fd7a:115c:a1e0::9187:413b";
    };
  };
  access = {
    tailscale.enable = true;
    global.enable = true;
  };
}
