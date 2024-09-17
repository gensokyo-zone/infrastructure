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
}
