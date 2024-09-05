_: {
  arch = "aarch64";
  type = "NixOS";
  ci.enable = false;
  modules = [
    ./nixos.nix
  ];
  deploy = {
    hostname = "10.1.1.50";
  };
  network.networks = {
    tail = {
      address4 = "100.71.135.42";
      address6 = "fd7a:115c:a1e0::4f01:872a";
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
