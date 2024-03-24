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
}
