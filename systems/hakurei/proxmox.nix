_: {
  proxmox = {
    vm.id = 103;
    container = {
      enable = true;
      lxc.configJsonFile = ./lxc.json;
    };
    network.interfaces = {
      net0 = {
        macAddress = "BC:24:11:C4:66:A7";
        address4 = "10.1.1.41/24";
        address6 = "auto";
      };
    };
  };
}
