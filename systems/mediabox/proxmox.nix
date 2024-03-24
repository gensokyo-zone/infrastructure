_: {
  proxmox = {
    vm.id = 102;
    container = {
      enable = true;
      lxc.configJsonFile = ./lxc.json;
    };
    network.interfaces = {
      net0 = {
        macAddress = "BC:24:11:34:F4:A8";
        address4 = "10.1.1.44/24";
        address6 = "auto";
      };
      net1.internal.enable = true;
    };
  };
}
