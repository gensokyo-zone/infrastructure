_: {
  arch = "aarch64";
  type = "NixOS";
  ci.allowFailure = true;
  access.online.enable = false;
  modules = [
    ./nixos.nix
  ];
  deploy = {
    hostname = "10.1.1.50";
  };
  network.networks = {
    tail = {
      #address4 = "100.70.124.79";
      #address6 = "fd7a:115c:a1e0::b001:7c4f";
    };
    local = {
      macAddress = "02:ba:46:f8:40:52";
      address4 = "10.1.1.50";
    };
  };
  exports = {
    services = {
      tailscale.enable = true;
    };
  };
}
