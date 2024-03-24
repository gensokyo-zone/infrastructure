_: {
  proxmox = {
    vm.id = 104;
    container = {
      enable = true;
      privileged = true;
      lxc.configJsonFile = ./lxc.json;
    };
    network.interfaces = {
      net0 = {
        macAddress = "BC:24:11:C4:66:A8";
        address4 = "10.1.1.45/24";
        address6 = "auto";
      };
      net1.internal.enable = true;
    };
  };
}
