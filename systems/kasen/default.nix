_: {
  imports = [
  ];
  # TODO: get an aarch64-linux builder on aya!
  ci.enable = false;
  arch = "aarch64";
  type = "NixOS";
  modules = [
    ./nixos.nix
  ];
  exports = {
    services = {
      tailscale.enable = true;
      nginx.enable = true;
      openwebrx.enable = true;
      rtl_tcp.enable = true;
    };
  };
  network.networks = {
    tail = {
      address4 = "100.80.196.57";
      address6 = "fd7a:115c:a1e0::5b01:c439";
    };
    local = {
      macAddress = "b8:27:eb:7e:e2:41";
      address4 = "10.1.1.49";
    };
  };
}
