_: {
  imports = [
    ./proxmox.nix
  ];
  arch = "x86_64";
  type = "NixOS";
  ci.allowFailure = true;
  access.online.enable = false;
  modules = [
    ./nixos.nix
  ];
  network.networks = {
    tail = {
      address4 = "100.73.157.122";
      address6 = "fd7a:115c:a1e0::1f01:9d7a";
    };
  };
  exports = {
    services = {
      tailscale.enable = true;
    };
  };
}
