_: {
  imports = [
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
      address4 = "100.70.124.79";
      address6 = "fd7a:115c:a1e0::b001:7c4f";
    };
  };
  exports = {
    services = {
      promtail.enable = false;
      prometheus-exporters-node.enable = false;
      tailscale.enable = true;
    };
  };
}
