_: {
  proxmox = {
    vm.id = 101;
    container = {
      enable = true;
      lxc.configJsonFile = ./lxc.json;
    };
    network.interfaces = {
      net0 = {
        macAddress = "BC:24:11:CC:66:57";
        address4 = "10.1.1.39/24";
        address6 = "auto";
      };
      net1.internal.enable = true;
    };
  };
  network.networks = {
    tail = {
      address4 = "100.74.104.29";
      address6 = "fd7a:115c:a1e0::fd01:681d";
    };
  };
}
