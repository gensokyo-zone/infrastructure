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
      address4 = "100.78.97.73";
      address6 = "fd7a:115c:a1e0::d834:6149";
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
