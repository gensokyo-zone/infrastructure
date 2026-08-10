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
      address4 = "100.78.130.44";
      address6 = "fd7a:115c:a1e0::6c34:822c";
    };
  };
  exports = {
    prometheus = {
      push.enable = false;
      exporter.enable = false;
    };
    services = {
      tailscale.enable = true;
    };
  };
}
