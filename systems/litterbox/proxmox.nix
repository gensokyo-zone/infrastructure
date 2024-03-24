_: {
  proxmox = {
    vm.id = 106;
    container = {
      enable = true;
      lxc.configJsonFile = ./lxc.json;
    };
    network.interfaces = {
      net0 = {
        mdns.enable = true;
        macAddress = "BC:24:11:C4:66:AB";
        address4 = "auto";
        address6 = "auto";
      };
    };
  };
}
