_: {
  proxmox = {
    vm.id = 109;
    container = {
      enable = true;
      lxc.configJsonFile = ./lxc.json;
    };
    network.interfaces = {
      net0 = {
        mdns.enable = true;
        macAddress = "BC:24:11:C4:66:AD";
        address4 = "10.1.1.51/24";
        address6 = "auto";
      };
    };
  };
  network.networks = {
    tail = {
      address4 = "100.73.157.122";
      address6 = "fd7a:115c:a1e0::1f01:9d7a";
    };
  };
}
