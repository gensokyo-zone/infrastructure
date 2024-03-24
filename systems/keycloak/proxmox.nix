_: {
  proxmox = {
    vm.id = 107;
    container = {
      enable = true;
      lxc.configJsonFile = ./lxc.json;
    };
    network.interfaces = {
      net0 = {
        macAddress = "BC:24:11:C4:66:AC";
        address4 = "10.1.1.48/24";
        address6 = "auto";
      };
      net1.internal.enable = true;
    };
  };
}
